#!/bin/bash
#set -x
# Ler o UID:  sudo nfc-anticol
# Escrever o UID:   sudo nfc-mfsetuid 1234ACD
# Limpar o Cartão: sudo nfc-mfsetuid -f
# 
#------------------------------------------------------
# Very Nice!
#------------------------------------------------------
clear
cat <<EOF
 
 .----------------.  .----------------.  .----------------.  .----------------.  .----------------.  .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. || .--------------. || .--------------. |
| |    ______    | || |   _    _     | || | ____    ____ | || |   ______     | || |     __       | || |  _________   | |
| |  .' ___  |   | || |  | |  | |    | || ||_   \  /   _|| || |  |_   _ \    | || |    /  |      | || | |  _   _  |  | |
| | / .'   \_|   | || |  | |__| |_   | || |  |   \/   |  | || |    | |_) |   | || |    `| |      | || | |_/ | | \_|  | |
| | | |    ____  | || |  |____   _|  | || |  | |\  /| |  | || |    |  __'.   | || |     | |      | || |     | |      | |
| | \ `.___]  _| | || |      _| |_   | || | _| |_\/_| |_ | || |   _| |__) |  | || |    _| |_     | || |    _| |_     | |
| |  `._____.'   | || |     |_____|  | || ||_____||_____|| || |  |_______/   | || |   |_____|    | || |   |_____|    | |
| |              | || |              | || |              | || |              | || |              | || |              | |
| '--------------' || '--------------' || '--------------' || '--------------' || '--------------' || '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'  '----------------'  '----------------' 

EOF
#----------------------------------------
# Variaveis	
#----------------------------------------
DUMP_CARTAO="./card_data"
LADO_LEITURA="A" # Can be A or B 
#----------------------------------------
# PRE: 
#----------------------------------------
if [ $(/usr/bin/id -u) -ne 0 ]; then 
 printf " ### ERRO - Tem que estar como ROOT, ANIMAL!\n\n"
 exit 1
fi
 
if [ "$(/bin/uname --kernel-release)" != "4.18.3" ]; then 
 echo ""
 echo " ### INFO - Kernel do Linux versão igual ou superior 4.18.3"
 echo ""
fi
# 
if [ ! -d ${DUMP_CARTAO} ]; then 
 mkdir -p -m 0700 ${DUMP_CARTAO} >/dev/null 2>&1
fi
#
PROGRAM="$(/usr/bin/basename ${0})"
MFOC="/usr/local/bin/mfoc"           # apt-get install mfoc
ANTICOL="/usr/bin/nfc-anticol"       # apt-get install libnfc-examples
NFC_POLL="/usr/bin/nfc-poll"         # apt-get install libnfc-examples
NFC_SETUID="/usr/bin/nfc-mfsetuid"   # apt-get install libnfc-examples
NFC_LIST="/usr/bin/nfc-list"         # apt-get install libnfc-bin
NFC_CLASSIC="/usr/bin/nfc-mfclassic" # apt-get install libnfc-bin
TIMESTAMP="$(date '+%Y_%m_%d_%H%M%S')"
#
for UTIL in ${MFOC} ${ANTICOL} ${NFC_LIST} ${NFC_POLL} ${NFC_SETUID} ${NFC_CLASSIC}; do 
 if [ ! -x ${UTIL} ];then 
  echo " ### ERRO - aplicativos ${UTIL} não encontrados!"
 printf "\n Ajuda o animal de como instalar as dependencias:\n
 /usr/local/bin/mfoc    # apt-get install mfoc
 /usr/bin/nfc-mfclassic # apt-get install libnfc-bin
 /usr/bin/nfc-list      # apt-get install libnfc-bin
 /usr/bin/nfc-anticol   # apt-get install libnfc-examples
 /usr/bin/nfc-mfssetuid # apt-get install libnfc-examples
 /usr/bin/nfc-poll      # apt-get install libnfc-examples\n\n"
  exit 1
 fi
done
#----------------------------------------
# Funções
#----------------------------------------
function DETECTA_LEITOR() {
 LEITOR_CARTAO=0
 while [ ${LEITOR_CARTAO} -eq 0 ]; do
  LER_DADOS="$(${NFC_LIST} 2>&1)"
  LEITOR_CARTAO=$(echo "${LER_DADOS}"|grep -c -E "^NFC device:.*opened$")
 sleep 1
 done
 return 0
}
#----------------------------------------
# MAIN
#----------------------------------------
printf " %-55s" "Detectando o Leitor..."
DETECTA_LEITOR
echo "[OK]"
#
READ_CARD_LOOP=1
while [ ${READ_CARD_LOOP} -eq 1 ]; do
 printf " %-55s" "Coloque o cartão original..."
 LER_UID_COMP="FALSE"
 while [ "${LER_UID_COMP}" == "FALSE" ]; do 
  DATA="$(${ANTICOL} 2>&1)"
  FAILED=$(echo ${DATA}|grep -c "Erro: Nenhum cartão disponivel.")
  if [ ${FAILED} -eq 0 ]; then 
   CARD_UID=$(echo "${DATA}"|grep "UID:"|awk '{print $2}')
   CARD_ATQA=$(echo "${DATA}"|grep "ATQA:"|awk '{print $2}')
   CARD_SAK=$(echo "${DATA}"|grep "SAK:"|awk '{print $2}')
   if [ "${CARD_UID}" == "" -o "${CARD_ATQA}" == "" -o "${CARD_SAK}" == "" ]; then 
    sleep .5
   else
    LER_UID_COMP="Sucesso!"
   fi
  fi
 done
 echo "[OK]"
 #
 printf "\n ##### Em Execução... #####"
 printf "\n %-55s" "$(date) Clonando ID-Card com UID: ${CARD_UID} (ATQA:${CARD_ATQA}/SAK:${CARD_SAK}) "
 ${MFOC} -O ${DUMP_CARTAO:-.}/${CARD_UID}.${TIMESTAMP}.mfd > ${PROGRAM}.log 2>${PROGRAM}.error
 if [ $? -ne 0 ]; then 
  printf "\n ##### FALHA !!!! #####\n\n"
  READ_CARD_LOOP=1
 else 
  READ_CARD_LOOP=0
  printf "\n %-55s" "$(date) Clone Completo do ID-Card com UID: ${CARD_UID} (ATQA:${CARD_ATQA}/SAK:${CARD_SAK}) "
 fi
done 
#-------------------------------------------------
# ESPERA CARTAO
#-------------------------------------------------
sleep .5
printf "\n\n %-55s" "Remova o cartão original"
CARTAO_REMOV=0
while [ ${CARTAO_REMOV} -eq 0 ]; do
 ${NFC_POLL} > /dev/null 2>&1
 if [ $? -eq 0 ]; then 
  CARTAO_REMOV=1
 fi
done
echo "[OK]"
#-------------------------------------------------
# ESPERA CARTAO
#-------------------------------------------------
PERMITE_ESCRITA=0
NEW_UID="${UID}"
while [ ${PERMITE_ESCRITA} -eq 0 ]; do
printf " %-55s" "Coloque o cartao em branco!"
 LER_NOVO_UID="FALSE"
 while [ "${LER_NOVO_UID}" == "FALSE" ]; do 
  NEW_DATA="$(${ANTICOL} 2>&1)"
  NOVO_FAILED=$(echo ${NEW_DATA}|grep -c "Erro: Nenhuma Tag encontrada")
  if [ ${NOVO_FAILED} -eq 0 ]; then 
   NOVO_CARD_UID=$(echo "${NEW_DATA}"|grep "UID:"|awk '{print $2}')
   NOVO_CARD_ATQA=$(echo "${NEW_DATA}"|grep "ATQA:"|awk '{print $2}')
   NOVO_CARD_SAK=$(echo "${NEW_DATA}"|grep "SAK:"|awk '{print $2}')
   if [ "${NOVO_CARD_UID}" == "" -o "${NOVO_CARD_ATQA}" == "" -o "${NOVO_CARD_SAK}" == "" ]; then 
    sleep .5
   else
    LER_NOVO_UID="Sucesso!"
   fi
  fi
 done
 if [ "${CARD_UID}" == "${NOVO_CARD_UID}" ]; then 
  echo "[AVISO!]"
  printf "\n ### O novo cartão possui o mesmo UID do antigo!\n\n"
  read -r -p " Deseja Sobreescrever ? Y/N " resposta
  if [[ "$resposta" =~ ^([yY][eE][sS]|[yY])+$ ]]
   then
    PERMITE_ESCRITA=1
  else
   PERMITE_ESCRITA=0
   sleep .5
   printf "\n %-55s" "Remova o cartao original... "
   CARTAO_REMOV=0
   while [ ${CARTAO_REMOV} -eq 0 ]; do
    ${NFC_POLL} > /dev/null 2>&1
    if [ $? -eq 0 ]; then 
     CARTAO_REMOV=1
    fi
   done
   echo "[OK]"
  fi
 else
  echo "[OK]"
  PERMITE_ESCRITA=1
 fi
done
#----------------------------------------
#  GRAVAR CARTÃO
#----------------------------------------
printf "\n %-55s" "Escrevendo UID: ${CARD_UID} no novo cartão"
${NFC_SETUID} ${CARD_UID} >> ${PROGRAM}.log 2>${PROGRAM}.error
if [ $? -ne 0 ]; then 
 echo "[ERROR]"
 printf "\n ### ERRO - ERRO AO ESCREVER NO BLOCO DE UID"
 exit 1
else
 echo "[OK]"
fi
printf " %-55s\n\n" "Escrevendo (${LADO_LEITURA} side) dados do cartão original:"
${NFC_CLASSIC} w ${LADO_LEITURA} ${DUMP_CARTAO:-.}/${CARD_UID}.${TIMESTAMP}.mfd | tee -a ${PROGRAM}.log 2>${PROGRAM}.error
echo ""
