#!/bin/bash

#Essa função é apenas para ficar parecendo que está trabalhando...na verdade é de brincadeira
criando_site(){
echo -n "Criando site"
sleep 1
echo -n "."
sleep 1
echo -n "."
sleep 1
echo -n "."
}

#Essa função verifica se os programas existem, se não ele instala
programas(){

if [ -e /etc/init.d/apache2 ]
then
echo "Você tem o Apache instalado!"
apache="sim"
else
echo "Você não pode criar um site, por que não tem um servidor instalado"
echo -n "Você deseja instalar agora? (s/n) "
read resposta

   if [ $resposta = "s" ]
   then
      apt-get install apache2
      echo "Pronto, agora você pode continuar..."
      apache="sim"
   else
      echo "Você não pode continuar se não instalar o Apache!"
      sleep 2
      exit
   fi
fi

echo "Escolha uma opção:"
echo " 1) Instalar e/ou configurar um servidor DNS (BIND) "
echo " 2) Configurar localmente "
echo ""
echo -n "Opção escolhida: "
read opcao

case $opcao in
1)

   if [ -e /usr/sbin/named ]
   then
      echo "Você tem um servidor DNS"
      bind9="sim"
   else
      apt-get install bind9
      echo "Pronto, agora você tem um servidor DNS"
      bind9="sim"
   fi
;;
2)
echo "O seu servidor resolverá localmente"
bind9="não"
;;
*)
echo "Opção inválida"
sleep 2
clear
programas
esac


}

#Tela da saida do programa
sair(){

echo ""
echo -n "Acabou por aqui, escolha uma opção: "
echo ""
echo "1) Desejo voltar ao menu inicial"
echo "2) Desejo fazer novamente a configuração"
echo "3) Desejo sair do programa"
echo ""

echo -n "Opção escolhida: "
read opcao

case $opcao in
1)
menu
;;
2)
$funcao
;;
3)
exit
;;
*)
echo -n "Opção inválida"
sleep 1
sair
esac

}

#Criar entradas no DNS
entradas(){

funcao="entradas"

echo -n "Nome da entrada (ex. ftp) "
read entrada

echo -n "Tipo de entrada: (A /CNAME) "
read tipo

#Se a entrada for A ele cria um FQDN
if [ tipo = "a" -o tipo = "A" ]
then
echo -n "Você deseja criar um FQDN? (ex. debian) "
read fqdn
echo -n "Qual a interface do computador? (ex. 192.168.0.2) "
read interface
echo "$entrada   IN   A   $interface" >> /etc/bind/db.$dominio
/etc/init.d/bind9 restart

echo -n "Criar mais entradas? (s/n)"
read resposta

   if [ $resposta = "s" ]
   then
      entradas
   else
      sair
   fi
#Se for qualquer outra coisa ele cria um CNAME
else

echo -n "Utilizando um FQDN - nome do servidor: (ex. debian) "
read fqdn
echo "$entrada   IN   CNAME   $fqdn.$dominio." >> /etc/bind/db.$dominio
/etc/init.d/bind9 restart

echo -n "Criar mais entradas? (s/n)"
read resposta
   if [ $resposta = "s" ]
   then
      entradas
   else
      sair
   fi

fi

}

#Se o BIND 9 existir ou a pessoa escolher o servidor DNS
bind_criar(){

funcao="bind_criar"

echo "Configurando DNS (BIND)"

echo -n "Qual é o número da sua interface? (ex. 192.168.0.2) "
read interface

echo -n "Qual é o nome do seu servidor? (ex. debian) "
read servidor

echo -n "Qual é a primeira entrada? (www) "
read entrada

#Coloca as entradas no arquivo named.conf.local
echo "zone \"$dominio\" {
        type master;
        file \"/etc/bind/db.$dominio\";
};" >> /etc/bind/named.conf.local


#Cria o arquivo do BIND
touch /etc/bind/db.$dominio

echo ";
; BIND - Entradas para o dominio - $dominio
;
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $dominio.
@       IN      A       $interface
$servidor   IN   A   $interface
$entrada   IN   CNAME   $servidor.$dominio." > /etc/bind/db.$dominio

#Redireciona para a função de mais entradas
echo -n "Você deseja colocar mais entradas no seu arquivo de DNS? (s/n) "
read mais_entradas

   if [ $mais_entradas = "s" ]
   then
      entradas
   else
      /etc/init.d/bind9 restart      
      sair
   fi

}

#Se não for usar o BIND
localmente(){
echo "Configurando dominio localmente..."
echo "127.0.0.1      $dns" >> /etc/hosts
sair
}


#Cria só um dominio, sem o Apache
dominio(){

funcao="dominio"

echo -n "Digite o nome do dominio: (ex. dominio.com) "
read dominio

#Vai para função bind criar
bind_criar

#Redireciona para a função entradas
echo -n "Você deseja colocar mais entradas no seu arquivo de DNS? (s/n) "
read mais_entradas

   if [ $mais_entradas = "s" ]
   then
      entradas
   else
      /etc/init.d/bind9 restart      
      sair
   fi

}


#Coloca um servidor DNS para o Linux
servidor_dns(){

clear
funcao="servidor_dns"

echo -n "Qual é o número do seu servidor DNS? (192.168.0.2) "
read servidor

echo "nameserver $servidor" >> /etc/resolv.conf

echo -n "Você deseja fazer o teste se o servidor está vivo? (s/n) "
read resposta

ping -c 5 $servidor

sair
}

#Função para criar sites automaticamente - DNS e Apache
criar_site_auto(){

clear
#Antes de criar um site, ele pergunta se você quer usar localmente ou usar um
#servidor DNS (bind9)
programas

funcao="criar_site_auto"

echo -n "Digite o nome do dominio: (ex. dominio.com) "
read dominio

echo -n "Digite a pasta de hospedagem: (/var/www/) "
read caminho

echo -n "Esse é o caminho completo \"$caminho$dominio\"? (s/n) "
read resposta

if [ $resposta = "s" ]
then
mkdir $caminho$dominio
echo "Pasta criada, continuando..."
else
sair
fi

echo -n "Que protocolo você deseja utilizar? (http/https) "
read protocolo

#Verificando a resposta do protocolo e fazendo o que o usuário pediu
   case $protocolo in
   http)
      echo "Utilizando HTTP, porta 80"
      porta="80"
      echo "Escrevendo os arquivos..."
      ssl_1="#SSLEngine On"
      ssl_2="#SSLCertificateFile /"
   ;;
   https)
      echo "Utilizando HTTPS, porta 443"
      porta="443"
      echo "Escrevendo configurações em: \"/certificados/\""

      if [ -e /certificados ]
      then
         openssl req $@ -new -x509 -days 365 -nodes -out /certificados/$dominio.pem -keyout /certificados/$dominio.pem
         chmod 777 -R /certificados/
         ssl_1="SSLEngine On"
         ssl_2="SSLCertificateFile /certificados/$dominio.pem"
      else
         mkdir /certificados/
         openssl req $@ -new -x509 -days 365 -nodes -out /certificados/$dominio.pem -keyout /certificados/$dominio.pem
         chmod 777 -R /certificados/      
         ssl_1="SSLEngine On"
         ssl_2="SSLCertificateFile /certificados/$dominio.pem"
      fi
   ;;
   *)
      echo "Utilizando HTTP, porta 80"
      porta="80"
      echo "Escrevendo os arquivos..."
      ssl_1="#SSLEngine On"
      ssl_2="#SSLCertificateFile /"
   esac

echo -n "Qual entrada DNS você deseja utilizar no site? (ex. www.dominio.com) "
read dns

echo -n "Você deseja fazer um redirecionamento para um outro site? (s/n) "
read redirecionar

#Verifica se é para redirecionar
   if [ $redirecionar = "s" ]
   then
      echo -n "Para qual site? (ex. http://www.site.com) "
      read redirecionar
      redirect="RedirectPermanent / $redirecionar"
   else
      redirect="#RedirectPermanent /"
   fi


#Configuração básica do Apache2
touch /etc/apache2/sites-available/$dominio
echo "<VirtualHost *:$porta>" > /etc/apache2/sites-available/$dominio
echo "   ServerName $dns" >> /etc/apache2/sites-available/$dominio
echo "   DocumentRoot $caminho$dominio" >> /etc/apache2/sites-available/$dominio
echo "   $ssl_1" >> /etc/apache2/sites-available/$dominio
echo "   $ssl_2" >> /etc/apache2/sites-available/$dominio
echo "   $redirect" >> /etc/apache2/sites-available/$dominio
echo "</VirtualHost>" >> /etc/apache2/sites-available/$dominio
a2ensite $dominio
a2enmod ssl
/etc/init.d/apache2 reload

echo -n "Você deseja criar um arquivo para teste? (s/n) "
read teste

   if [ $teste = "s" ]
   then
      criando_site
      touch $caminho$dominio/index.html
      echo "<html>
<head>
<meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">
</head>
<body>
<h1>Minha primeira página!</h1>
</body>
</html>" > $caminho$dominio/index.html
      echo "Site criado."
   else
      echo "Site criado."
fi

#Chama a função bind9 para escrever ou não as entradas 
      if [ $bind9 = "sim" ]
      then
         bind_criar

      else
         localmente

      fi

}


#Função para criar sites manualmente - Só o Apache
criar_site_manual(){

clear

funcao="criar_site_manual"

echo -n "Digite o nome do dominio: (ex. dominio.com)"
read dominio

echo -n "Digite a pasta de hospedagem: (/var/www/) "
read caminho

echo -n "Esse é o caminho completo \"$caminho$dominio\"? (s/n) "
read resposta

   if [ $resposta = "s" ]
   then
      mkdir $caminho$dominio
      echo "Pasta criada, continuando..."
   else
      sair
   fi

echo -n "Que protocolo você deseja utilizar? (http/https) "
read protocolo

   case $protocolo in
   http)
      echo "Utilizando HTTP, porta 80"
      porta="80"
      echo "Escrevendo os arquivos..."
      ssl_1="#SSLEngine On"
      ssl_2="#SSLCertificateFile /"
   ;;
   https)
      echo "Utilizando HTTPS, porta 443"
      porta="443"
      echo "Escrevendo configurações em: \"/certificados/\""

      if [ -e /certificados ]
      then
         openssl req $@ -new -x509 -days 365 -nodes -out /certificados/$dominio.pem -keyout /certificados/$dominio.pem
         chmod 777 -R /certificados/
         ssl_1="SSLEngine On"
         ssl_2="SSLCertificateFile /certificados/$dominio.pem"
      else
         mkdir /certificados/
         openssl req $@ -new -x509 -days 365 -nodes -out /certificados/$dominio.pem -keyout /certificados/$dominio.pem
         chmod 777 -R /certificados/      
         ssl_1="SSLEngine On"
         ssl_2="SSLCertificateFile /certificados/$dominio.pem"
      fi
   ;;
   *)
      echo "Utilizando HTTP, porta 80"
      porta="80"
      echo "Escrevendo os arquivos..."
      ssl_1="#SSLEngine On"
      ssl_2="#SSLCertificateFile /"
   esac

echo -n "Qual entrada DNS você deseja utilizar (ex. www.dominio.com) "
read dns

echo -n "Você deseja fazer um redirecionamento para um outro site? (s/n) "
read redirecionar

#Verifica se é para redirecionar
   if [ $redirecionar = "s" ]
   then
      echo "Para qual site? (ex. http://www.site.com) "
      read $redirecionar
      redirect="RedirectPermanent / $redirecionar"
   else
      redirect="#RedirectPermanent /"
   fi

#Configuração básica do Apache2
touch /etc/apache2/sites-available/$dominio
echo "<VirtualHost *:$porta>" > /etc/apache2/sites-available/$dominio
echo "   ServerName $dns" >> /etc/apache2/sites-available/$dominio
echo "   DocumentRoot $caminho$dominio" >> /etc/apache2/sites-available/$dominio
echo "   $ssl_1" >> /etc/apache2/sites-available/$dominio
echo "   $ssl_2" >> /etc/apache2/sites-available/$dominio
echo "   $redirect" >> /etc/apache2/sites-available/$dominio
echo "</VirtualHost>" >> /etc/apache2/sites-available/$dominio
a2ensite $dominio
a2enmod ssl
/etc/init.d/apache2 reload

echo -n "Você deseja criar um arquivo para teste? (s/n) "
read teste

   if [ $teste = "s" ]
   then
      criando_site
      touch $caminho$dominio/index.html
      echo "<html>
<head>
<meta content=\"text/html; charset=utf-8\" http-equiv=\"content-type\">
</head>
<body>
<h1>Minha primeira página!</h1>
</body>
</html>" > $caminho$dominio/index.html
      echo "Site criato"
      sair
   else
      echo "Site criado."
      sair
   fi

}

#Função que testa o servidor
testar_servidor(){

clear
funcao="testar_servidor"

echo ""
mii-tool
echo ""
echo -n "Qual é o número da sua interface de rede? "
read interface

echo ""
ifconfig $interface
echo ""
echo -n "Essa é a sua rede, digite um número próximo a esse..."
echo -n "Qual é o nome ou número IP do servidor? (192.168.0.2) "
read servidor

echo ""
ping -c 5 $servidor
sair

}

#Função para instalar esse script no computador
instalar(){
echo -n "Você deseja instalar esse script no sistema? (s/n) "
read resposta

if [ $resposta = "s" ]
then

#Copia o arquivo para o SBIN do sistema
   cp ./apache /sbin
   chmod 755 /sbin/apache
   
   if [ -e /sbin/apache ]
   then
#Se a copia foi bem sucedida ele mostra a mensagem e volta para o menu principal
   echo "Instalação efetuada com sucesso!"
   echo "Agora para usar esse script digite \"apache\" no terminal"
   sleep 4
   menu
   

#Se não existir ele mostra o erro e volta para o menu principal
   else
   echo "Ocorreu um erro ao instalar..."
   sleep 2
   menu
   fi

else

#Se for digitado qualquer coisa diferente de s, volta para o menu principal
   echo "Ops, você digitou algo errado, voltando ao menu principal"
   sleep 2
   menu

fi
}


#Função para desistalar o script do sistema
desistalar(){

echo -n "Você deseja desistalar esse script do sistema? (s/n) "
read resposta

if [ $resposta = "s" ]
then

rm /sbin/apache

   if [ -e /sbin/apache ]
   then
   echo "Não pode desistalar esse script"
   echo "Dê um \"rm /sbin/apache \" para fazer isso manualmente"
   sleep 5
   exit

   else

   echo "Script desistalado com sucesso!"
   sleep 2
   exit
   fi

exit

else

#Se for digitado qualquer coisa diferente de s, volta para o menu principal
echo "Ops, você digitou algo errado, voltando ao menu principal"
sleep 2
menu

fi
}

menu() {

clear
funcao="menu"

#Verifica se o script está instalado

if [ -e /sbin/apache ]
then
instalado="sim"
else
instalado="não"
fi


echo "========================================"
echo "|    Configurador Apache e DNS         |"
echo "========================================"
echo "| 1) Criar novo dominio DNS            |"
echo "| 2) Configurar servidor DNS           |"
echo "========================================"
echo "| 3) Criar novo site (DNS e Apache)    |"
echo "| 4) Criar novo site (Só apache)       |"
echo "========================================"
echo "| 5) Testar um servidor                |"
echo "========================================"

#Escreve instalar ou desistalar dependendo da váriavel
   if [ $instalado = "sim" ]
   then
      echo "| d) Desistalar esse script do sistema |"
   else
      echo "| i) Instalar esse script no sistema   |"
      
   fi

echo "| q) Para sair                         |"
echo "========================================"
echo ""
echo -n "Opção escolhida: "
read opcao

case $opcao in
1)
dominio
;;
2)
servidor_dns
;;
3)
criar_site_auto
;;
4)
criar_site_manual
;;
5)
testar_servidor
;;
i)
instalar
;;
d)
desistalar
;;
q)
exit
;;
*)
echo -n "Opção inválida"
sleep 1
menu

esac
}

#Inicia o menu
menu
