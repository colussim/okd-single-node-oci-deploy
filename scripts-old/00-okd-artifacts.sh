export OKD_VERSION=4.19.0-okd-scos.15
export ARCH=x86_64

curl -L https://github.com/okd-project/okd/releases/download/$OKD_VERSION/openshift-client-linux-$OKD_VERSION.tar.gz -o oc.tar.gz

tar zxf oc.tar.gz
chmod +x oc
