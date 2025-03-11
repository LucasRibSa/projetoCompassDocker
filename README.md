# Projeto AWS Compass UOL
Este projeto faz parte da atividade da Compass UOL. A proposta consiste em configurar uma infraestrutura escalável para rodar a aplicação WordPress, utilizando tecnologias como Docker, Auto Scaling Group (ASG), Classic Load Balancer (CLB), Amazon RDS e Amazon EFS.

## Tecnologias usadas
- **VPC:** Rede virtual na região us-east-1 com sub-redes públicas e privadas.
- **Auto Scaling Group (ASG):** Gerencia 2 instâncias EC2 (escaláveis) com o Amazon Linux 2.
- **Classic Load Balancer:** Distribui o tráfego HTTP (porta 80) entre as instâncias.
- **Amazon RDS:** Instância MySQL para o banco de dados WordPress.
- **Amazon EFS:** Armazena os arquivos do WordPress (wp-content) compartilhados entre as instâncias.
- **Docker e Docker Compose:** Executa o WordPress e os serviços de monitoramento.
  

## 1 - Crie uma VPC com as seguintes configurações:
- 2 sub-redes públicas em diferentes zonas de disponibilidade 
- Conecte as sub-redes públicas a um Internet Gateway.
- 2 sub-redes privadas em zonas de disponibilidade distintas
- Crie um NAT Gateway em uma das sub-redes públicas para permitir que as instâncias privadas acessem a internet.
- Configure a tabela de rotas para garantir que as sub-redes privadas acessem a internet via NAT Gateway e as públicas via Internet Gateway.

## 2 - Criar os Security Groups
- Vá em "Security Groups" no console AWS.
- Crie 4 SGs (wp-lb-sg, wp-ec2-sg, wp-rds-sg, wp-efs-sg).
- Adicione as regras de entrada e saída conforme a tabela abaixo.

| Componente | SG Nome | Inbound | Outbound |
|------------|--------|---------|----------|
| Classic Load Balancer |  wp-lb-sg  |  HTTP 80 (0.0.0.0/0) | HTTP 80 (wp-ec2-sg) |
| EC2 Instances (ASG) |	wp-ec2-sg |	HTTP 80 (wp-lb-sg), NFS 2049 (wp-ec2-sg) |	NFS 2049 (wp-efs-sg) |
| RDS MySQL	| wp-rds-sg |	MYSQL/Aurora 3306 (wp-ec2-sg)| 	Todos (0.0.0.0/0) |
| EFS	| wp-efs-sg |	TCP 2049 (wp-ec2-sg) |	Todos (0.0.0.0/0) |

## 3 - Crie uma instâcia RDS
- Engine: MySQL.
- Tipo: db.t3.micro 
- Sub-rede privada 
- Security Group: Permitir acesso à porta 3306 apenas das instâncias EC2.

  ```
  mysql -h <seu endpoint> -u admin -psenha
  CREATE DATABASE wordpress;
  ```
  
## 4 - Criar o Sistema de Arquivos EFS
- Crie um sistema de arquivos EFS dentro da mesma VPC utilizada pelas instâncias EC2.
- Configure o wp-efs-sg como Security Group.

## 5 - Criar o Classic Load Balancer
- Nome: Escolha um nome (ex.: CLB-WordPress).
- Listener:
  - Load Balancer Protocol: HTTP, Porta: 80.
  - Instance Protocol: HTTP, Porta: 80.
- Sub-redes: Selecione as 2 sub-redes públicas.
- Configure o wp-lb-sg como Security Group.
- Health Check:
  - Protocol: HTTP.
  - Path: /wp-admin/install.php 
  - Intervalo: 30 segundos, Threshold: 2.
- Após a criação, anote o DNS do ELB (ex.: wordpress-elb-243643.us-east-1.elb.amazonaws.com).
- Edite as configurações de persistência de cookies: selecione "Gerado pelo balanceador de carga", com Período de expiração: 0.
  
## 6 - Criar o Launch Template
- AMI: Amazon Linux 2.
- Tipo: t2.micro.
- Configure o wp-ec2-sg como Security Group.
- Adicione uma IAM role com as políticas:
   - AmazonElasticFileSystemFullAccess.
   - AmazonSSMManagedInstanceCore.

### Script `user_data.sh`
```bash
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
```

## 7 - Criar o Auto Scaling Group

- Min: 2 instâncias, Max: 2 (ou mais, se preferir).
- Sub-redes: As 2 sub-redes privadas.
- Associe o Auto Scaling Group ao Classic Load Balancer.

## 8 - Testar as funcionalidades

- Teste a aplicação usando o DNS do Classic Load Balancer no navegador: http://loadbalancer-xxxxx.us-east-1.elb.amazonaws.com.
- Complete a instalação do WordPress.
- Faça o upload de uma imagem no WordPress e verifique se ela foi salva corretamente no EFS.
