# PXL Playlist Parser - Geautomatiseerde AWS Deployments

Deze map bevat alle Terraform-code, scripts en documentatie om de Playlist Parser applicatie automatisch uit te rollen naar AWS. De oplossing voldoet aan de eisen uit de opdracht door gebruik te maken van herbruikbare modules, gescheiden omgevingen (staging en production), remote state management en automatische deployment scripts.

## Inhoud

- `terraform/global/state`: Terraform-configuratie om de remote state infrastructuur (S3 + DynamoDB) te voorzien.
- `terraform/modules`: Herbruikbare modules voor networking, compute en database.
- `terraform/environments/<env>`: Environment-specifieke configuraties voor `staging` en `production`.
- `scripts`: Hulpscripts om deployments consistent uit te voeren.

## Prerequisites

| Tool        | Versie            | Opmerking |
|-------------|-------------------|-----------|
| Terraform   | >= 1.5.0          | getest met 1.6.x |
| AWS CLI     | >= 2.15           | vereist om credentials te configureren |
| Terragrunt  | *optioneel*       | niet nodig voor deze oplossing |
| Git         | >= 2.40           | gebruikt door de user-data scripts |

Zorg dat je AWS-credentials beschikbaar zijn voor Terraform. Gebruik bij voorkeur een profiel met beperkte rechten dat de volgende acties mag uitvoeren:

- Beheer van VPC, Subnets, Route Tables, Internet/NAT Gateways
- EC2 instances, Auto Scaling Groups, Launch Templates
- Application Load Balancers en Target Groups
- IAM rollen en instance profiles
- S3 buckets en DynamoDB tabellen (voor state)
- AWS Backup resources

## Remote State Management

### 1. Voorbereiding

De remote state infrastructuur wordt aangemaakt via `terraform/global/state`.

1. Kopieer `terraform.tfvars.example` naar `terraform.tfvars` binnen deze map en vul de waarden in:

```hcl
region               = "eu-west-1"
bucket_name          = "pxl-playlistparser-terraform-state"
dynamodb_table_name  = "pxl-playlistparser-terraform-locks"
tags = {
  Project = "playlistparser"
}
```

> ⚠️ Gebruik unieke namen voor bucket en tabel.

2. Initialise en apply:

```bash
cd terraform/global/state
terraform init
terraform apply
```

Na afloop bestaan er:

- Een S3 bucket met versioning, encryptie en public access block
- Een DynamoDB tabel met hash key `LockID`

### 2. Backend configureren

Elke environment map bevat een `backend.hcl.example`. Kopieer deze naar `backend.hcl` en vul de waarden uit de vorige stap in. Voor staging ziet dat er zo uit:

```hcl
bucket         = "pxl-playlistparser-terraform-state"
key            = "staging/terraform.tfstate"
region         = "eu-west-1"
dynamodb_table = "pxl-playlistparser-terraform-locks"
encrypt        = true
```

Production gebruikt dezelfde bucket/table maar een andere key (`production/terraform.tfstate`).

## Secrets en tfvars

Secrets worden **niet** gecommit. Maak in elke environment map een tfvars-bestand op basis van het voorbeeld:

- `staging/staging.tfvars.example`
- `production/production.tfvars.example`

Kopieer het voorbeeld naar respectievelijk `staging.tfvars` en `production.tfvars` en vul:

- `app_repository`: Git URL van de Playlist Parser broncode
- `spotify_client_id`, `spotify_client_secret`, `spotify_redirect_uri`
- AMI ID’s voor frontend, API en database
- Eventueel `ssh_key_name`
- De repository moet de folders `frontend/` en `api/` bevatten (zoals de meegeleverde projectstructuur).

De API user-data ontvangt automatisch de volgende environment variabelen:

| Variabele              | Omschrijving |
|------------------------|--------------|
| `DATABASE_URL`         | PostgreSQL connectiestring op basis van private IP + random wachtwoord |
| `SPOTIFY_CLIENT_ID`    | Doorgegeven via tfvars |
| `SPOTIFY_CLIENT_SECRET`| Doorgegeven via tfvars |
| `SPOTIFY_REDIRECT_URI` | Environment-specifieke redirect |
| `APP_SOURCE_URL`       | Git repository URL |
| `PORT`                 | API poort (standaard 3000) |

De database user-data genereert de database, gebruiker en mount het EBS-volume voor persistente data. Wachtwoorden worden via `random_password` in de Terraform state beheerd.

## Deployment stappen

### Staging

```bash
cp terraform/environments/staging/backend.hcl.example terraform/environments/staging/backend.hcl
cp terraform/environments/staging/staging.tfvars.example terraform/environments/staging/staging.tfvars
# vul backend.hcl en staging.tfvars in

./scripts/deploy_staging.sh
```

### Production

```bash
cp terraform/environments/production/backend.hcl.example terraform/environments/production/backend.hcl
cp terraform/environments/production/production.tfvars.example terraform/environments/production/production.tfvars
# vul backend.hcl en production.tfvars in

./scripts/deploy_production.sh
```

De scripts voeren automatisch `terraform init` met backend-configuratie en `terraform apply` uit. Gebruik extra Terraform flags door ze na het script te plaatsen (bv. `./scripts/deploy_staging.sh -auto-approve`).

## Structuur & Modules

### Networking module

- Maakt een VPC per environment met configureerbare CIDR.
- Creëert minimaal twee public en twee private subnets verdeeld over verschillende AZ’s.
- Internet Gateway + één NAT Gateway per VPC.
- Route tables voor public en private subnets.

### Compute module

- Application Load Balancer met path-based routing (`/` → frontend, `/api/*` → API).
- Security groups volgens least privilege (internet → ALB → private tiers → database).
- Launch templates voor frontend en API met user-data scripts die de applicatie bouwen en deployen.
- Auto Scaling Groups met configureerbare capaciteit (1 in staging, 2 in production).
- CloudWatch Agent installatie en logging configuraties voor nginx en de API.

### Database module

- Dedicated EC2 instance met apart EBS-data volume (default 50 GiB staging, 100 GiB production).
- User-data script configureert PostgreSQL, mount het data volume en activeert CloudWatch logging.
- AWS Backup-plan met dagelijkse snapshots (retentie 7 dagen staging, 30 dagen production).

## Outputs

Beide environments leveren o.a. de volgende outputs:

- `alb_dns_name` – public URL voor de applicatie.
- `environment`, `vpc_id`, `vpc_cidr` – identificatie van de infrastructuur.
- `database_private_ip` en `database_connection_string` – troubleshooting & connectie (laatste is sensitive).
- `frontend_instance_ids`, `api_instance_ids`, `database_instance_id` – overzicht van de EC2 resources.
- `backup_plan_id` – referentie naar de AWS Backup configuratie.

Bekijk de outputs via `terraform output` in de desbetreffende environment map.

## Verificatie

1. **State management** – controleer dat `terraform.tfstate` in S3 staat en dat tijdens een `terraform apply` een lock record in DynamoDB verschijnt.
2. **Netwerkisolatie** – staging en production hebben aparte VPC’s, ALB’s, NAT gateways en EC2-instanties.
3. **Applicatie** – ALB DNS naam bezoeken en nagaan dat frontend en API (via `/api/healthz`) correct antwoorden.
4. **Database persistency** – voeg testdata toe, reboot de database instance en controleer dat data behouden blijft.
5. **Spotify OAuth** – configureer redirect URI’s per environment en doorloop de login-flow.
6. **Backups** – in AWS Backup moet een dagelijkse job zichtbaar zijn met de ingestelde retentie.

## Tips

- Gebruik verschillende AWS profielen (bv. `default` en `prod`) of zet `AWS_PROFILE` voor je deployment.
- Houd de AMI’s up-to-date met de nodige applicatie dependencies (Node 18.x, nginx, PostgreSQL 15).
- CloudWatch log groups worden automatisch aangemaakt door de agent. Voeg indien gewenst alarms toe voor CPU/disk (default rules: CPU >80% gedurende 5 min, disk >90%).
- Voor troubleshooting kan je `terraform destroy` gebruiken op één environment zonder de andere te beïnvloeden dankzij de gescheiden state files.

## Extra

- De scripts accepteren extra Terraform-argumenten (zoals `-auto-approve`).
- Voeg een DNS-record of ACM-certificaat toe voor HTTPS zodra de basis werkt.
- Terragrunt kan eenvoudig geïntroduceerd worden door de bestaande modules als source te gebruiken; de mapstructuur houdt hier al rekening mee.
