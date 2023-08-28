CERT_FOLDER=config/certs
SECRET_FOLDER=/secrets

if [ x${ELASTIC_PASSWORD} == x ]; then
    echo "Set the ELASTIC_PASSWORD environment variable in the .env file and "\
        "pass it as environment variable";
    exit 1;
elif [ x${KIBANA_PASSWORD} == x ]; then
    echo "Set the KIBANA_PASSWORD environment variable in the .env file and "\
        "pass it as environment variable";
    exit 1;
elif [ x${LOGSTASH_WRITER_PASSWORD} == x ]; then
    echo "Set the LOGSTASH_WRITER_PASSWORD environment variable in the .env file and "\
        "pass it as environment variable";
    exit 1;
elif [ x${LOGSTASH_READER_PASSWORD} == x ]; then
    echo "Set the LOGSTASH_READER_PASSWORD environment variable in the .env file and "\
        "pass it as environment variable";
    exit 1;
fi;
if [ ! -f config/certs/ca.zip ]; then
    echo "Creating CA";
    bin/elasticsearch-certutil ca --silent --pem -out ${CERT_FOLDER}/ca.zip;
    unzip ${CERT_FOLDER}/ca.zip -d ${CERT_FOLDER};
    if [ -f /setup/ca/ca.crt ]; then
        echo "Removing old /setup/ca/ca.crt";
        rm -rf /setup/ca;
    fi;
    mkdir -p ${SECRET_FOLDER}/ca
    rm -rf ${SECRET_FOLDER}/ca/*
    cp ${CERT_FOLDER}/ca/ca.crt ${SECRET_FOLDER}/ca/ca.crt;
fi;
if [ ! -f ${SECRET_FOLDER}/ca/ca.crt ]; then
    echo "Copying /setup/ca/ca.crt";
    mkdir -p ${SECRET_FOLDER}/ca
    cp ${CERT_FOLDER}/ca/ca.crt ${SECRET_FOLDER}/ca/ca.crt;
fi;
if [ ! -f ${CERT_FOLDER}/certs.zip ]; then
    echo "Creating certs";
    echo -ne \
    "instances:\n"\
    "  - name: es\n"\
    "    dns:\n"\
    "      - es\n"\
    "      - localhost\n"\
    "    ip:\n"\
    "      - 127.0.0.1\n"\
    "  - name: logstash\n"\
    "    dns:\n"\
    "      - logstash\n"\
    "      - localhost\n"\
    "      - ${EXTERNAL_HOST}\n"\
    "    ip:\n"\
    "      - 127.0.0.1\n"\
    "      - ${EXTERNAL_IP}\n"\
    > ${CERT_FOLDER}/instances.yml;
    bin/elasticsearch-certutil cert --pem -out ${CERT_FOLDER}/certs.zip \
        --in ${CERT_FOLDER}/instances.yml --ca-cert ${CERT_FOLDER}/ca/ca.crt \
        --ca-key ${CERT_FOLDER}/ca/ca.key;
    ls -la ${CERT_FOLDER}/.
    cat ${CERT_FOLDER}/instances.yml
    unzip ${CERT_FOLDER}/certs.zip -d ${CERT_FOLDER};
fi;

EXTERNAL_CERT_FOLDER=${CERT_FOLDER}/external
if [ "${USE_EXTERNAL_CERT}" == "false" ] && [ ! -f ${SECRET_FOLDER}/external.pem ]; then
    echo "Creating external certs";
    mkdir -p ${EXTERNAL_CERT_FOLDER}/
    ls -la ${EXTERNAL_CERT_FOLDER}/
    rm -rf ${EXTERNAL_CERT_FOLDER}/external.*
    openssl req -new -newkey rsa:4096 -nodes -keyout ${EXTERNAL_CERT_FOLDER}/external.key \
        -out ${EXTERNAL_CERT_FOLDER}/external.csr -subj "/CN=localhost"
    openssl x509 -req -sha256 -days 3650 -in ${EXTERNAL_CERT_FOLDER}/external.csr \
        -signkey ${EXTERNAL_CERT_FOLDER}/external.key -out ${EXTERNAL_CERT_FOLDER}/external.pem
    cat ${EXTERNAL_CERT_FOLDER}/external.key >> ${EXTERNAL_CERT_FOLDER}/external.pem
    ls -la ${EXTERNAL_CERT_FOLDER}/.
    mkdir -p ${SECRET_FOLDER}/external/
    cp ${EXTERNAL_CERT_FOLDER}/external.pem ${SECRET_FOLDER}/external/external.pem;
else
    echo "Using external certs"
fi;

echo "Setting file permissions"
chown -R root:root ${CERT_FOLDER};
find ${CERT_FOLDER}/. -type d -exec chmod 750 \{\} \;;
find ${CERT_FOLDER}/. -type f -exec chmod 640 \{\} \;;

echo "Waiting for Elasticsearch availability";
until curl -s --cacert ${CERT_FOLDER}/ca/ca.crt ${ES_URL} | \
    grep -q "missing authentication credentials"; do sleep 30; done;
echo "Setting kibana_system password";
until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" https://es:9200/_security/user/kibana_system/_password \
    -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do sleep 10; done;

LOGSTASH_WRITER_ROLE_NAME=logstash_writer
GET_LOGSTASH_WRITER_ROLE=$(curl -s -X GET --cacert ${CERT_FOLDER}/ca/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
    ${ES_URL}/_security/role/$LOGSTASH_WRITER_ROLE_NAME)
printf "Get $LOGSTASH_WRITER_ROLE_NAME role output:\n$GET_LOGSTASH_WRITER_ROLE\n"
if [ ${GET_LOGSTASH_WRITER_ROLE} = "{}" ]; then
    echo "Creating logstash_writer role";
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" ${ES_URL}/_security/role/$LOGSTASH_WRITER_ROLE_NAME \
        -d "$(cat /setup/payloads/logstash_writer_role.json)" | grep -q "true"; do sleep 10; done;
fi;

LOGSTASH_READER_ROLE_NAME=logstash_reader
LOGSTASH_READER_ROLE=$(curl -s -X GET --cacert ${CERT_FOLDER}/ca/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
    ${ES_URL}/_security/role/$LOGSTASH_READER_ROLE_NAME)
printf "Get $LOGSTASH_READER_ROLE_NAME role output:\n$LOGSTASH_READER_ROLE\n"
if [ ${LOGSTASH_READER_ROLE} = "{}" ]; then
    echo "Creating grafana role";
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" ${ES_URL}/_security/role/$LOGSTASH_READER_ROLE_NAME \
        -d "$(cat /setup/payloads/logstash_reader_role.json)" | grep -q "true"; do sleep 10; done;
fi;

GET_LOGSTASH_WRITER_USER=$(curl -s -X GET --cacert ${CERT_FOLDER}/ca/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
    ${ES_URL}/_security/user/${LOGSTASH_WRITER_USER})
printf "Get $LOGSTASH_WRITER_USER output:\n$GET_LOGSTASH_WRITER_USER\n"
if [ ${GET_LOGSTASH_WRITER_USER} = "{}" ]; then
    echo "Creating $LOGSTASH_WRITER_USER";
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" ${ES_URL}/_security/user/${LOGSTASH_WRITER_USER} \
        -d "{\"password\":\"${LOGSTASH_WRITER_PASSWORD}\",\"roles\":[\"${LOGSTASH_WRITER_ROLE_NAME}\"]}" | \
        grep -q "true"; do sleep 10; done;
fi;

GET_LOGSTASH_READER_USER=$(curl -s -X GET --cacert ${CERT_FOLDER}/ca/ca.crt \
    -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
    ${ES_URL}/_security/user/${LOGSTASH_READER_USER})
printf "Get $LOGSTASH_READER_USER output:\n$GET_LOGSTASH_READER_USER\n"
if [ ${GET_LOGSTASH_READER_USER} = "{}" ]; then
    echo "Creating $LOGSTASH_READER_USER";
    until curl -s -X POST --cacert ${CERT_FOLDER}/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
        -H "Content-Type: application/json" ${ES_URL}/_security/user/${LOGSTASH_READER_USER} \
        -d "{\"password\":\"${LOGSTASH_READER_PASSWORD}\",\"roles\":[\"${LOGSTASH_READER_ROLE_NAME}\"]}" | \
        grep -q "true"; do sleep 10; done;
fi;
echo "All done!";