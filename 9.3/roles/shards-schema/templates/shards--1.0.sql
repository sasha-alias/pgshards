--- mapreduce proxy interfaces

CREATE SCHEMA IF NOT EXISTS shards;

CREATE OR REPLACE FUNCTION shards.from_all(query TEXT) RETURNS SETOF json AS
$$
    CLUSTER '{{cluster_name}}_cluster';
    RUN ON ALL;
    TARGET shards.__exec;
$$
LANGUAGE plproxy SECURITY DEFINER;

CREATE OR REPLACE FUNCTION shards.from_any(query TEXT) RETURNS SETOF json AS
$$
    CLUSTER '{{cluster_name}}_cluster';
    RUN ON ANY;
    TARGET shards.__exec;
$$
LANGUAGE plproxy SECURITY DEFINER;

CREATE OR REPLACE FUNCTION shards.on_all(query text, OUT shard TEXT, OUT status INTEGER, OUT nrows INTEGER, OUT result TEXT) RETURNS SETOF record AS
$$
    CLUSTER '{{cluster_name}}_cluster';
    RUN ON ALL;
    TARGET shards.__run;
$$
LANGUAGE plproxy SECURITY DEFINER;

GRANT USAGE ON SCHEMA shards TO PUBLIC;

CREATE OR REPLACE FUNCTION shards.on_any(query text, OUT shard TEXT, OUT status INTEGER, OUT nrows INTEGER, OUT result TEXT) RETURNS SETOF record AS
$$
    CLUSTER '{{cluster_name}}_cluster';
    RUN ON ANY;
    TARGET shards.__run;
$$
LANGUAGE plproxy SECURITY DEFINER;

GRANT USAGE ON SCHEMA shards TO PUBLIC;

--- mapreduce shard part

CREATE OR REPLACE FUNCTION shards.__exec(query text)
RETURNS SETOF json AS $$
BEGIN
    RETURN QUERY EXECUTE 'SELECT row_to_json(q.*) FROM ('||query||') q';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION shards.__run(query text, OUT shard TEXT,	OUT status INTEGER, OUT nrows INTEGER, OUT result TEXT) RETURNS SETOF record AS $$
    import json
    from plpy import spiexceptions
    rv = plpy.execute('SELECT current_database()')
    try:
        result = plpy.execute(query)
        retList = []
        if result:
            for r in result:
                retList .append(r)
        yield(rv[0]['current_database'], result.status(), result.nrows(), json.dumps(retList))
    except Exception, ex:
        yield(rv[0]['current_database'], 0, 0, "Error: "+str(ex))
$$ LANGUAGE plpythonu SECURITY DEFINER;


GRANT USAGE ON SCHEMA shards TO PUBLIC;

--- global sequences

CREATE SEQUENCE shards.global_id_seq;

CREATE TABLE shards.conf (
    shard_number INTEGER,   -- number of current shard in cluster
    max_shards INTEGER,     -- maximum shards number in a given cluster
    db_code BIGINT          -- unique code fro given partition used to make id's unique
);

SELECT pg_catalog.pg_extension_config_dump('shards.conf', '');

CREATE OR REPLACE FUNCTION shards.global_id()
RETURNS BIGINT LANGUAGE sql AS
$$
    SELECT db_code + nextval('shards.global_id_seq') FROM shards.conf;
$$
VOLATILE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION shards.set_conf(
    i_shard_number INTEGER,
    i_max_shards INTEGER,
    i_db_code INTEGER
)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS
$$ -- initialize or change partiton configutration
DECLARE
    r_conf RECORD;
BEGIN
    IF i_shard_number > i_max_shards THEN
        RAISE EXCEPTION 'Shard number (%) should not be bigger than maximum number of partitons (%)' , i_shard_number, i_max_shards;
    END IF;

    SELECT * FROM shards.conf INTO r_conf;

    IF FOUND THEN
        r_conf.db_code = r_conf.db_code::bigint << 54 ;
        -- 54 means, that 54 bits are for the actual number, and the other
        -- 9 bits are for the partition number.
        raise notice 'Shard configuration has changed!';
        raise notice 'Shard number: % -> %', r_conf.shard_number, i_shard_number;
        raise notice 'Max shards: % -> %', r_conf.max_shards, i_max_shards;
        raise notice 'DB code: % -> %', r_conf.db_code, i_db_code;
        DELETE FROM shards.conf;
    END IF;

    IF i_db_code < 1 or 511 < i_db_code THEN -- 9 bits for the db_code
        RAISE EXCEPTION  'Db code (%) should be between 0 and 511', i_db_code;
    END IF;

    INSERT INTO shards.conf (shard_number, max_shards, db_code)

    VALUES (i_shard_number, i_max_shards, i_db_code::bigint<<54);

    RETURN 'OK';
end;
$$;


--- owner

CREATE OR REPLACE FUNCTION shards.create_owner(i_user text, i_pass text)
RETURNS BIGINT LANGUAGE plpythonu AS
$$
    import os

    bouncer_userlist = '/etc/pgbouncer/userlist.txt'

    user_name = plpy.quote_ident(i_user.lower().strip())
    password = plpy.quote_literal(i_pass)

    rv = plpy.execute("SELECT NULL FROM pg_roles where rolname = '"+user_name+"'", 1)

    if len(rv) == 0:  # if user doesn't exist
        plpy.execute("CREATE USER %s WITH PASSWORD %s" % (user_name, password))
    else:
        plpy.execute("ALTER USER %s WITH PASSWORD %s" % (user_name, password))

    rv = plpy.execute("SELECT NULL FROM pg_catalog.pg_foreign_server where srvname = '{{cluster_name}}_cluster'", 1)

    if len(rv) == 1:  # if cluster exists

        rv = plpy.execute("SELECT NULL FROM pg_catalog.pg_user_mappings where srvname = '{{cluster_name}}_cluster' and usename = 'public'", 1)

        if len(rv) == 1:  # if user mapping exists
            plpy.execute("DROP USER MAPPING IF EXISTS FOR PUBLIC SERVER {{cluster_name}}_cluster")

        plpy.execute("CREATE USER MAPPING FOR PUBLIC SERVER {{cluster_name}}_cluster OPTIONS (user '"+user_name+"', password "+password+")")

    # update pgboucer userlist
    if os.path.isfile(bouncer_userlist):
        f = open(bouncer_userlist,'r')
        linelist = f.readlines()
        f.close()
        f = open(bouncer_userlist,'w')
        for line in linelist:
            if '"'+user_name+'" ' not in line.lower().strip():
                f.write(line)
        f.close()
        f = open(bouncer_userlist,'a')
        f.write('"'+user_name+'" "'+password.strip("'")+'"\n')
        f.close()

$$
VOLATILE SECURITY DEFINER;

---

CREATE OR REPLACE FUNCTION shards.set_owner(i_schema text, i_user text)
RETURNS BIGINT
AS
$$
DECLARE
    stmt text;
BEGIN
    FOR stmt IN
        SELECT 'ALTER FUNCTION '||i_schema||'.'||proname ||
            '(' || pg_catalog.pg_get_function_identity_arguments(pr.oid)
            || ') OWNER TO '||i_user
        FROM pg_proc pr join pg_namespace n on pr.pronamespace = n.oid
        WHERE n.nspname = i_schema
        UNION ALL
        SELECT 'ALTER TABLE '||i_schema||'.'||tablename
            || ' OWNER TO '||i_user
        FROM pg_tables
        WHERE schemaname = i_schema
    LOOP
        EXECUTE stmt;
    END LOOP;

    EXECUTE 'GRANT ALL ON ALL TABLES IN SCHEMA '||i_schema||' TO '||i_user;
    EXECUTE 'GRANT USAGE ON SCHEMA '||i_schema||' TO '||i_user;
    EXECUTE 'GRANT CREATE ON SCHEMA '||i_schema||' TO '||i_user;

    RETURN 0;
END;
$$
LANGUAGE plpgsql SECURITY DEFINER;

