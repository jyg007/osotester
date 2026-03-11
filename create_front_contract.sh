#!/bin/bash

# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0

#terraform init
#terraform destroy -auto-approve

LOCAL_PLAY="./testerdata" 

DOMAIN="frontendplugintester"
XML="$LOCAL_PLAY/domain_front.xml"

if ! virsh dominfo "$DOMAIN" >/dev/null 2>&1; then
    echo "Domain $DOMAIN not defined. Defining it..."
    virsh define "$XML"
fi
if ! virsh net-info testnetfront >/dev/null 2>&1; then
    echo "testnetfront  not defined. Defining it..."
    virsh net-define $LOCAL_PLAY/testnet.xml
    virsh net-start testnetfront
fi

# List of targets
targets=("oso-ca" "app" "user")

# 1️⃣ Generate .key files
for name in "${targets[@]}"; do
    keyfile="$LOCAL_PLAY/$name.key"
    if [ ! -f "$keyfile" ]; then
        echo "Generating RSA key for $name..."
        openssl genrsa -out "$keyfile" 4096
        chmod 0600 "$keyfile"
    fi
done

# 2️⃣ Generate .csr files
for name in "${targets[@]}"; do
    keyfile="$LOCAL_PLAY/$name.key"
    csrfile="$LOCAL_PLAY/$name.csr"
    if [ ! -f "$csrfile" ]; then
        echo "Generating CSR for $name..."
        openssl req -key "$keyfile" -new -out "$csrfile" -nodes \
            -subj "/C=US/O=IBM OSO/CN=$name/"
    fi
done

# 3️⃣ Generate .crt files
for name in "${targets[@]}"; do
    csrfile="$LOCAL_PLAY/$name.csr"
    crtfile="$LOCAL_PLAY/$name.crt"
    extfile="$LOCAL_PLAY/ext.cnf"
    if [ ! -f "$crtfile" ]; then
        echo "Generating certificate for $name..."
        if [[ "$name" == *"oso-ca"* ]]; then
            # Self-signed CA
            openssl x509 -req -in "$csrfile" \
                -signkey "$LOCAL_PLAY/oso-ca.key" \
                -CAcreateserial \
                -out "$crtfile" -days 365 \
                -extensions v3_ca -extfile "$extfile"
        else
            # Signed by CA
            openssl x509 -req -in "$csrfile" \
                -CAkey "$LOCAL_PLAY/oso-ca.key" \
                -CA "$LOCAL_PLAY/oso-ca.crt" \
                -CAcreateserial \
                -out "$crtfile" -days 365 \
                -extensions v3_crt -extfile "$extfile"
        fi
    fi
done

. ./terraform.tfvars

HPVSNAME=frontend

sed -e 's/<<-EOT/$(cat <<-EOT /' -e 's/^EOT/EOT\n)/' ./terraform.tfvars > ./o.$$ 
for i in IMAGE SYSLOG REGISTRY MACHINE1 MACHINE1_DESCRIPTION MACHINE1_HKD_B24 HSMDOMAIN1 SECRET_B24 MKVP HELLO HPCR_CERT
do
  sed -i "s/^$i/export $i/" ./o.$$
done

export APPKEY=$(<$LOCAL_PLAY/app.key)
export APPCRT=$(<$LOCAL_PLAY/app.crt)
export OSOCA=$(<$LOCAL_PLAY/oso-ca.crt)
#export OSOCA=$(awk '{printf "%s\\n",$0}' oso-ca.crt)
#export APPKEY=$(awk '{printf "%s\\n",$0}' app.key)
#export APPCRT=$(awk '{printf "%s\\n",$0}' app.crt)

. ./o.$$
rm ./o.$$

ENV=`pwd`/$HPVSNAME.env.yml
envsubst < $LOCAL_PLAY/env.tpl > $ENV
sed -i '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ s/^/      /' $ENV
sed -i '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/ s/^/      /' $ENV

CONTRACT_KEY=.ibm-hyper-protect-container-runtime-encrypt.crt

envsubst < $LOCAL_PLAY/hpcr_contractkey.tpl > $CONTRACT_KEY

if [[ ! -f $1 ]]
then
	echo "Missing contract file $1"
	exit 2
fi

echo  "workload: $(cat $1)" >  $HPVSNAME.yml

PASSWORD=`openssl rand -base64 32`

ENCRYPTED_PASSWORD="$(echo -n "$PASSWORD" | base64 -d | openssl pkeyutl -encrypt -pubin -inkey <(openssl x509 -in $CONTRACT_KEY -pubkey -noout) |  base64 -w0)"
ENCRYPTED_ENV="$(echo -n "$PASSWORD" | base64 -d | openssl enc -aes-256-cbc -pbkdf2 -pass stdin -in "$ENV" | base64 -w0)"
echo "env: hyper-protect-basic.${ENCRYPTED_PASSWORD}.${ENCRYPTED_ENV}" >> $HPVSNAME.yml


#echo "env: hyper-protect-basic.${ENCRYPTED_PASSWORD}.${ENCRYPTED_ENV}" >> $HPVSNAME.yml
 
rm $CONTRACT_KEY

mv $HPVSNAME.yml $LOCAL_PLAY/user-data

touch $LOCAL_PLAY/vendor-data
echo "local-hostname: frontendplugintester" > $LOCAL_PLAY/meta-data

#genisoimage -output /var/lib/libvirt/images/frontendplugintester-cloudinit -volid cidata -joliet -rock vendor-data user-data meta-data network-config
genisoimage -quiet -output /var/lib/libvirt/images/frontendplugintester-cloudinit -volid cidata -joliet -rock $LOCAL_PLAY/vendor-data $LOCAL_PLAY/user-data $LOCAL_PLAY/meta-data 

qemu-img create -q -f qcow2 /var/lib/libvirt/images/frontendplugintester-overlay.qcow2 10G

