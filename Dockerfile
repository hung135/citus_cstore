FROM postgres:10

MAINTAINER Hung Nguyen (hung135@hotmail.com) 
#merged together from 2 git projects
ARG VERSION=8.2.2
LABEL maintainer="Citus Data https://citusdata.com" \
      org.label-schema.name="Citus" \
      org.label-schema.description="Scalable PostgreSQL for multi-tenant and real-time workloads" \
      org.label-schema.url="https://www.citusdata.com" \
      org.label-schema.vcs-url="https://github.com/citusdata/citus" \
      org.label-schema.vendor="Citus Data, Inc." \
      org.label-schema.version=${VERSION} \
      org.label-schema.schema-version="1.0"

ENV CITUS_VERSION ${VERSION}.citus-1

# install Citus
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
    && curl -s https://install.citusdata.com/community/deb.sh | bash \
    && apt-get install -y postgresql-$PG_MAJOR-citus-8.2=$CITUS_VERSION \
                          postgresql-$PG_MAJOR-hll=2.12.citus-1 \
                          postgresql-$PG_MAJOR-topn=2.2.0 \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*

# add citus to default PostgreSQL config
RUN echo "shared_preload_libraries='citus'" >> /usr/share/postgresql/postgresql.conf.sample
#cstore

RUN apt-get update && apt-get install -y \
    git \
    libpq-dev \
    libprotobuf-c0-dev \
    make \
    postgresql-server-dev-$PG_MAJOR \
    protobuf-c-compiler \
    gcc

RUN cd /tmp && git clone -b v1.6.0 https://github.com/citusdata/cstore_fdw.git

RUN cd /tmp/cstore_fdw && PATH=/usr/local/pgsql/bin/:$PATH make && PATH=/usr/local/pgsql/bin/:$PATH make install
#RUN cp /usr/share/postgresql/9.6/extension/* /usr/share/postgresql/10/extension/
#RUN cp /usr/share/postgresql/postgresql.conf.sample /etc/postgresql/postgresql.conf
#RUN cp /usr/share/postgresql/postgresql.conf.sample /var/lib/postgresql/data/postgresql.conf

#RUN sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'cstore_fdw'/g" /var/lib/postgresql/data/postgresql.conf



RUN sed -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'cstore_fdw'/g" /usr/share/postgresql/postgresql.conf.sample
# add scripts to run after initdb
COPY 000-configure-stats.sh 001-create-citus-extension.sql /docker-entrypoint-initdb.d/
#RUN echo 'citus.enable_statistics_collection=off' >> "${PGDATA}/postgresql.conf"
#RUN pg_ctl -D "${PGDATA}" reload -s

# add health check script
COPY pg_healthcheck /

HEALTHCHECK --interval=4s --start-period=6s CMD ./pg_healthcheck