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
| EC2 Instances (ASG) |	wp-ec2-sg |	HTTP 80 (wp-lb-sg), NFS 2049 (wp-ec2-sg) |	MYSQL/Aurora 3306 (wp-rds-sg), NFS 2049 (wp-efs-sg), HTTPS 443 (0.0.0.0/0) |
| RDS MySQL	| wp-rds-sg |	MYSQL/Aurora 3306 (wp-ec2-sg)| 	Todos (0.0.0.0/0) |
| EFS	| wp-efs-sg |	TCP 2049 (wp-ec2-sg) |	Todos (0.0.0.0/0) |

## 3 - Crie uma instâcia RDS
- Engine: MySQL.
- Tipo: db.t2.micro 
- Sub-rede privada 
- Security Group: Permitir acesso à porta 3306 apenas das instâncias EC2.

  ```
  mysql -h <seu endpoint> -u admin -2803Psfac.
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

- Adicione o Script user_data:

  ```
  #!/bin/bash
  sudo apt-get update -y && sudo apt-get upgrade -y
  sudo apt-get install -y docker.io curl
  sudo systemctl enable --now docker
  DOCKER_COMPOSE_VERSION="2.20.2"
  DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
  sudo curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  USER_NAME=$(whoami)
  sudo usermod -aG docker "$USER_NAME"
  if systemctl is-active --quiet docker; then
    echo "Docker está rodando com sucesso!"
  else
    echo "Erro ao iniciar o Docker."
    exit 1
  fi
  ```

## 7 - Criar o Auto Scaling Group

- Min: 2 instâncias, Max: 2 (ou mais, se preferir).
- Sub-redes: As 2 sub-redes privadas.
- Associe o Auto Scaling Group ao Classic Load Balancer.

## 8 - Testar as funcionalidades

- Teste a aplicação usando o DNS do Classic Load Balancer no navegador: http://loadbalancer-xxxxx.us-east-1.elb.amazonaws.com.
- Complete a instalação do WordPress.
- Faça o upload de uma imagem no WordPress e verifique se ela foi salva corretamente no EFS.
