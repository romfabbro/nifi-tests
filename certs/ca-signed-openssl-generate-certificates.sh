RENEW_CA=0
while getopts ":ca" option; do
   case $option in
      h) RENEW_CA=1
         exit;;
   esac
done


PASS=
WORK_DIR="ca-openssl"
mkdir -p $WORK_DIR
cd $WORK_DIR

rm -rf jks pem p12 key
mkdir -p jks pem p12 key

if [[ $RENEW_CA -eq 1 ]]
then
    echo "Generate CA certificate"
    openssl req -x509 -nodes -new \
            -days 365 \
            -subj '/CN=nifi-ca' \
            -keyout ca.key -out ca.crt
else 
    echo "CA certificate won't be generated"
fi

# openssl genrsa -out server.key 4096
echo "Generate Nifi host certificate ...."
openssl req -new -newkey rsa:4096 -keyout key/key-nifi.pem -out pem/cert-nifi.pem \
    -subj '/CN=nifi' -addext "subjectAltName = DNS:nifi, DNS:localhost" -addext extendedKeyUsage=serverAuth,clientAuth \
    -passin "pass:${PASS}" -passout "pass:${PASS}"
echo "... Done !"

echo "\\n ******************************"
echo "Sign Nifi host certificate with CA ...."
openssl x509 -req -in pem/cert-nifi.pem \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -days 365 \
  -out pem/signed-cert-nifi.pem
echo "... Done !"

echo "\\n ******************************"
echo "Generate client certificate ...."
openssl req -new -newkey rsa:4096 -keyout key/key-bane.pem -out pem/cert-bane.pem \
    -subj '/CN=bane' -addext "subjectAltName = DNS:bane" -addext extendedKeyUsage=serverAuth,clientAuth \
    -passin "pass:${PASS}" -passout "pass:${PASS}"
echo "... Done !"

echo "\\n ******************************"
echo "Sign client certificate with CA ...."
openssl x509 -req -in pem/cert-bane.pem \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -days 365 \
  -out pem/signed-cert-bane.pem
echo "... Done !"

echo "\\n ******************************"
echo "Export in p12 format"
openssl pkcs12 -export -name nifi -out p12/nifi.p12 -inkey key/key-nifi.pem \
    -in pem/signed-cert-nifi.pem -passin "pass:${PASS}" -passout "pass:${PASS}" 

openssl pkcs12 -export -name bane -out p12/bane.p12 -inkey key/key-bane.pem \
    -in pem/signed-cert-bane.pem -passin "pass:${PASS}" -passout "pass:${PASS}"

echo "\\n ******************************"
echo "Generate NiFi keystore JKS"
keytool -keystore jks/nifi-ks.jks -genkey -alias nifi \
    -storetype JKS -keysize 4096 -keyalg rsa -dname CN=nifi -storepass ${PASS} -keypass ${PASS}
keytool -delete -alias nifi -keystore jks/nifi-ks.jks -storepass ${PASS}

keytool -importkeystore -srckeystore p12/nifi.p12 -srcstoretype pkcs12  -alias nifi \
        -deststoretype jks -destkeystore jks/nifi-ks.jks -srcstorepass ${PASS} -deststorepass ${PASS} -destkeypass ${PASS}

echo "\\n ******************************"
echo "Generate NiFi Truststore JKS"
keytool -keystore jks/truststore.jks -genkey -alias nifi-ca \
    -storetype JKS -keysize 4096 -keyalg rsa -dname CN=nifi-ca -storepass ${PASS} -keypass ${PASS}
keytool -delete -alias nifi-ca -keystore jks/truststore.jks -storepass ${PASS}

keytool -importcert -file ca.crt -alias nifi-ca -keystore jks/truststore.jks -storepass ${PASS} -v -noprompt
keytool -importcert -file pem/signed-cert-bane.pem -alias bane -keystore jks/truststore.jks -storepass ${PASS} -v -noprompt
keytool -importcert -file pem/signed-cert-nifi.pem -alias nifi -keystore jks/truststore.jks -storepass ${PASS} -v -noprompt


if [[ $PRINT_OUTPUT_RESULT -eq 1 ]]
then 
    echo "\\n ******************************"
    echo "Print client certificate"
    openssl x509 \
    --in pem/signed-cert-bane.pem \
    -text \
    --noout

    echo "\\n ******************************"
    echo "Print NiFi Truststore"
    keytool -list -v -keystore jks/truststore.jks -storepass crdpxx
fi
