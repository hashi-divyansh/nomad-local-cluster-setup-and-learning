#!/bin/bash

echo "================================================"
echo "Nginx Service Diagnostic Script"
echo "================================================"
echo ""

echo "1. Checking VM Status..."
orb list
echo ""

echo "2. Checking if port 8080 is reachable on client VMs..."
for ip in 192.168.139.113 192.168.139.64 192.168.139.193; do
    echo "Testing $ip:8080..."
    nc -zv -w 2 $ip 8080 2>&1 || echo "  ❌ Port 8080 not reachable on $ip"
done
echo ""

echo "3. Checking Nomad job status..."
orb -m server-vm-0 'nomad job status nginx-demo 2>&1 | head -30'
echo ""

echo "4. Checking running Docker containers on client-vm-0..."
orb -m client-vm-0 'sudo docker ps'
echo ""

echo "5. Checking if nginx is listening on port 8080 inside client-vm-0..."
orb -m client-vm-0 'sudo ss -tlnp | grep 8080'
echo ""

echo "6. Testing nginx from inside client-vm-0..."
orb -m client-vm-0 'curl -s -m 2 localhost:8080 | head -5 2>&1 || echo "Failed to connect to localhost:8080"'
echo ""

echo "7. Checking Consul service registration..."
orb -m server-vm-0 'consul catalog services'
echo ""

echo "8. Checking Consul DNS for nginx-service..."
orb -m server-vm-0 'dig @localhost -p 8600 nginx-service.service.consul +short'
echo ""

echo "9. Checking Consul API for nginx-service..."
orb -m server-vm-0 'curl -s http://localhost:8500/v1/catalog/service/nginx-service | jq ".[].ServiceAddress" 2>&1 || curl -s http://localhost:8500/v1/catalog/service/nginx-service'
echo ""

echo "10. Checking Nomad allocation logs (first allocation)..."
orb -m server-vm-0 'nomad job status nginx-demo | grep -A 10 "Allocations" | tail -1 | awk "{print \$1}" | xargs -I {} nomad alloc logs {} | tail -20'
echo ""

echo "================================================"
echo "Diagnostic complete!"
echo "================================================"
