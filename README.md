# azure-iac v2 - baseline hosting of ForgeTask with an Azure PostgreSQL database

Goal: see the SaaS running on Azure and make signup / login / logout work, with users stored in
Azure Database for PostgreSQL. Everything else in the SaaS is out of scope.

## Parts
- terraform/: resource group, network, ACR, AKS, PostgreSQL Flexible Server (+ firewall rule).
- k8s/: backend, frontend and ingress manifests (backend runs with Spring profile "azure").
- app-patch/: the 2 small changes to put in YOUR FORK of the app (profile file + 2 pom dependencies).
- .github/workflows/: infra (terraform), deploy-app (build/push/deploy), aks-power (stop/start).

## Order
1. Fork JRV-XVI/oci-chatbot, create branch azure-compat, apply app-patch/ (see files), push.
2. Edit APP_REPO in .github/workflows/deploy-app.yml (your fork).
3. Create empty GitHub repo for this kit; run scripts/bootstrap.sh; create the secrets it prints plus:
   DB_USER (= pgadmin), DB_PASSWORD (new strong password), JWT_SECRET (openssl rand -base64 48),
   APP_REPO_TOKEN (only if the fork is private).
4. Push this kit to main -> workflow infra. Then run deploy-app.
5. Test: open the URL printed in the job summary, sign up, log in, log out.

## If Hibernate does not create the schema
Connect with psql and run:  CREATE SCHEMA IF NOT EXISTS app_user;   then restart the backend pod.

## Not validated
Written without running terraform validate, the workflows, or the app against PostgreSQL.
