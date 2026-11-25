# Imagen de PostgreSQL 18 con Patroni (etcd v3).
# docker build -t <registro>/patroni-pg18:1 patroni/ && docker push <registro>/patroni-pg18:1
FROM postgres:18

RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv curl \
 && python3 -m venv /opt/patroni \
 && /opt/patroni/bin/pip install --no-cache-dir "patroni[etcd3,psycopg3]>=4.0.6" \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/patroni/bin:${PATH}"
COPY --chmod=0755 entrypoint.sh /usr/local/bin/patroni-entrypoint.sh
USER postgres
EXPOSE 5432 8008
HEALTHCHECK --interval=10s --timeout=5s --retries=3 CMD curl -fs http://localhost:8008/health || exit 1
ENTRYPOINT ["/usr/local/bin/patroni-entrypoint.sh"]
