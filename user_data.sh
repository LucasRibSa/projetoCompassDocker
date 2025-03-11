#!/bin/bash
 
# Atualizar sistema
yum update -y
 
# Instalar Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
 
# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
 
# Instalar amazon-efs-utils e montar EFS
yum install -y amazon-efs-utils
 
# Criar diretório para montagem do EFS
mkdir -p /mnt/efs
 
# Montar o EFS manualmente
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-xxxxxxxxxxx.efs.us-east-1.amazonaws.com:/ /mnt/efs
 
# Adicionar montagem automática no /etc/fstab
echo "fs-xxxxxxxxxx.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0" | sudo tee -a /etc/fstab
 
# Criar docker-compose.yml no EFS (se ainda não existir)
if [ ! -f /mnt/efs/docker-compose.yml ]; then
  cat <<EOF > /mnt/efs/docker-compose.yml
version: '3'
services:
  wordpress:
    image: wordpress:latest
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: database-1.xxxxxxxxxxxx.regiao.rds.amazonaws.com
      WORDPRESS_DB_USER: admin
      WORDPRESS_DB_PASSWORD: suasenha
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - /mnt/efs:/var/www/html/wp-content
EOF
fi
 
# Iniciar o WordPress
cd /mnt/efs
sudo docker-compose up -d
