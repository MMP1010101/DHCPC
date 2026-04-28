#!/bin/bash

# Script para configurar IP estática en enp3s0 con el rango 172.16.160.0/24
# Autor: Script de configuración de red

# Colores para salida
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Este script debe ejecutarse como root (usar sudo)${NC}"
    exit 1
fi

# Función para validar número
validate_number() {
    if [[ ! "$1" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if [ "$1" -lt 1 ] || [ "$1" -gt 254 ]; then
        return 1
    fi
    return 0
}

# Solicitar el número de host
echo -e "${YELLOW}=== Configurador de IP Estática ===${NC}"
echo -e "Rango de red: ${GREEN}172.16.160.0/24${NC}"
echo ""
echo "Ingrese el número de host (1-254) para la IP:"
echo "La IP final será: 172.16.160.X"
echo ""

while true; do
    read -p "Número de host (1-254): " HOST_NUM
    
    if validate_number "$HOST_NUM"; then
        break
    else
        echo -e "${RED}Error: Ingrese un número válido entre 1 y 254${NC}"
    fi
done

# Construir la IP
IP_ADDRESS="172.16.160.$HOST_NUM/24"
GATEWAY="172.16.160.1"

echo ""
echo -e "${GREEN}Configuración seleccionada:${NC}"
echo "  IP: $IP_ADDRESS"
echo "  Gateway: $GATEWAY"
echo "  DNS: 8.8.8.8, 8.8.4.4"
echo ""

# Solicitar confirmación
read -p "¿Desea aplicar esta configuración? (s/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Configuración cancelada${NC}"
    exit 0
fi

# Ruta del archivo netplan (ajustar según tu sistema)
NETPLAN_FILE="/etc/netplan/00-installer-config.yaml"

# Crear backup del archivo actual si existe
if [ -f "$NETPLAN_FILE" ]; then
    BACKUP_FILE="${NETPLAN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}Backup creado: $BACKUP_FILE${NC}"
fi

# Leer la configuración actual y agregar solo enp3s0
if [ -f "$NETPLAN_FILE" ]; then
    # Crear el archivo temporal con la configuración modificada
    awk -v ip="$IP_ADDRESS" -v gw="$GATEWAY" '
    BEGIN { in_ethernets=0; printed_enp3s0=0 }
    /^network:/ { print; next }
    /^  ethernets:/ { print; in_ethernets=1; next }
    /^  version:/ { 
        if (!printed_enp3s0 && in_ethernets) {
            print "    enp3s0:"
            print "      dhcp4: no"
            print "      addresses:"
            print "        - " ip
            print "      routes:"
            print "        - to: default"
            print "          via: " gw
            print "      nameservers:"
            print "        addresses:"
            print "          - 8.8.8.8"
            print "          - 8.8.4.4"
            printed_enp3s0=1
        }
        print
        next
    }
    /^    enp3s0:/ { 
        # Saltar la configuración antigua de enp3s0 si existe
        print "    enp3s0:"
        print "      dhcp4: no"
        print "      addresses:"
        print "        - " ip
        print "      routes:"
        print "        - to: default"
        print "          via: " gw
        print "      nameservers:"
        print "        addresses:"
        print "          - 8.8.8.8"
        print "          - 8.8.4.4"
        printed_enp3s0=1
        # Saltar líneas hasta la siguiente interfaz o section
        while (getline > 0 && $0 ~ /^      /) { }
        if ($0 !~ /^$/) print
        next
    }
    { print }
    ' "$NETPLAN_FILE" > "${NETPLAN_FILE}.tmp"
    
    mv "${NETPLAN_FILE}.tmp" "$NETPLAN_FILE"
else
    # Si no existe el archivo, crear uno nuevo solo con enp3s0
    cat > "$NETPLAN_FILE" << EOF
# This is the network config written by 'subiquity'
network:
  ethernets:
    enp3s0:
      dhcp4: no
      addresses:
        - $IP_ADDRESS
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
  version: 2
EOF
fi

echo -e "${GREEN}Archivo netplan actualizado${NC}"
echo ""

# Aplicar la configuración
echo -e "${YELLOW}Aplicando configuración de red...${NC}"
netplan apply

if [ $? -eq 0 ]; then
    echo -e "${GREEN}¡Configuración aplicada exitosamente!${NC}"
    echo ""
    echo "Información de la interfaz enp3s0:"
    ip addr show enp3s0 | grep "inet "
    echo ""
    echo "Prueba de conectividad:"
    ping -c 3 $GATEWAY
else
    echo -e "${RED}Error al aplicar la configuración${NC}"
    echo "Restaurando backup..."
    if [ -f "$BACKUP_FILE" ]; then
        cp "$BACKUP_FILE" "$NETPLAN_FILE"
        netplan apply
    fi
    exit 1
fi

echo ""
echo -e "${GREEN}Configuración completada${NC}"
