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

echo ""
echo -e "${GREEN}Configuración seleccionada:${NC}"
echo "  IP: $IP_ADDRESS"
echo ""

# Solicitar confirmación
read -p "¿Desea aplicar esta configuración? (s/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Configuración cancelada${NC}"
    exit 0
fi

NETPLAN_FILE="/etc/netplan/00-installer-config.yaml"

# Hacer backup
cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Insertar enp3s0 antes de "version: 2", sin tocar nada más
sed -i "/^  version:/i\\    enp3s0:\n      dhcp4: no\n      addresses:\n        - $IP_ADDRESS" "$NETPLAN_FILE"

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
else
    echo -e "${RED}Error al aplicar la configuración${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Configuración completada${NC}"
