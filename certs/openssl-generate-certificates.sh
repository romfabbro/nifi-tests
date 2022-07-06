
PASS=

rm -rf openssl/jks openssl/pem openssl/p12 openssl/key
mkdir -p openssl/jks openssl/pem openssl/p12 openssl/key

openssl req -new -key server.key -out server.csr

openssl req -x509 -newkey rsa:4096 -keyout openssl/key/key-nifi.pem -out openssl/pem/cert-nifi.pem \
    -subj '/CN=nifi' -addext "subjectAltName = DNS:nifi" -addext extendedKeyUsage=serverAuth,clientAuth \
    -passin "pass:${PASS}" -passout "pass:${PASS}"
openssl pkcs12 -export -name nifi -out openssl/p12/nifi.p12 -inkey openssl/key/key-nifi.pem \
    -in openssl/pem/cert-nifi.pem -passin "pass:${PASS}" -passout "pass:${PASS}"

openssl req -x509 -newkey rsa:4096 -keyout openssl/key/key-bane.pem -out openssl/pem/cert-bane.pem \
    -subj '/CN=bane' -addext "subjectAltName = DNS:bane" -addext extendedKeyUsage=serverAuth,clientAuth \
    -passin "pass:${PASS}" -passout "pass:${PASS}"
openssl pkcs12 -export -name bane -out openssl/p12/bane.p12 -inkey openssl/key/key-bane.pem \
    -in openssl/pem/cert-bane.pem -passin "pass:${PASS}" -passout "pass:${PASS}"


keytool -keystore openssl/jks/nifi-ks.jks -genkey -alias nifi \
    -storetype JKS -keysize 4096 -keyalg rsa -dname CN=nifi -storepass ${PASS} -keypass ${PASS}
keytool -delete -alias nifi -keystore openssl/jks/nifi-ks.jks -storepass ${PASS}

keytool -importkeystore -srckeystore openssl/p12/nifi.p12 -srcstoretype pkcs12  -alias nifi \
        -deststoretype jks -destkeystore openssl/jks/nifi-ks.jks -srcstorepass ${PASS} -deststorepass ${PASS} -destkeypass ${PASS}


keytool -keystore openssl/jks/truststore.jks -genkey -alias nifi-ts \
    -storetype JKS -keysize 4096 -keyalg rsa -dname CN=nifi-ts -storepass ${PASS} -keypass ${PASS}
keytool -delete -alias nifi-ts -keystore openssl/jks/truststore.jks -storepass ${PASS}


keytool -importcert -file openssl/pem/cert-bane.pem -alias bane -keystore openssl/jks/truststore.jks -storepass ${PASS} -v -noprompt
keytool -importcert -file openssl/pem/cert-nifi.pem -alias nifi -keystore openssl/jks/truststore.jks -storepass ${PASS} -v -noprompt
