auths:
  "$REGISTRY12_URL":
    password: "$REGISTRY_PASSWORD"
    username: "$REGISTRY_USERNAME"
cacerts:
- certificate: "$REGISTRY_CA"
logging:
  syslog:
    hostname: "$SYSLOG12_HOSTNAME"
    port: $SYSLOG12_PORT
    server: | 
$SYSLOG12_SERVER_CERT
    cert: | 
$SYSLOG12_CLIENT_CERT
    key: |
$SYSLOG12_CLIENT_KEY
env:
    mode: frontend
    PORT: "4000"
    certs__app_key: |
$APPKEY
    certs__app_crt: |
$APPCRT
    certs__ca: | 
$OSOCA
    CONFIRMATION_FINGERPRINT:  ""
type: env
