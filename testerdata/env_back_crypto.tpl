host-attestation: 
  HKD-$MACHINE1:
    description:  $MACHINE1_DESCRIPTION
    host-key-doc: $MACHINE1_HKD_B24
  HKD-$MACHINE2:
    description:  $MACHINE2_DESCRIPTION
    host-key-doc: $MACHINE2_HKD_B24
crypto-pt: 
  lock: false
  index-1:
    type: secret
    domain-id: "$HSMDOMAIN1"
    secret: $SECRET_B24
    mkvp: $MKVP
  index-2:
    type: secret
    domain-id: "$HSMDOMAIN2"
    secret: $SECRET_B24
    mkvp: $MKVP
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
volumes:
  vault_vol:
    seed: "hello"
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
