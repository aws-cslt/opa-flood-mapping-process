### BEFORE BUILDING
Ensure AWS CloudFormation infrastructure is deployed.
Retrieve Process Table Name, Task Definition Name, and Flood Mapping Container Name from AWS Infrastructure.

### BUILD
Update flood mapping AWS ECR docker tag, and the AWS account number in below commands before running.
where <flood-mapping-AWS-ECR-docker-tag> is the ecr created by the processing cloud formation scripts. example opa-3d-ecr
``` bash
aws ecr get-login-password --region ca-central-1 | docker login --username AWS --password-stdin <aws-account-number>.dkr.ecr.ca-central-1.amazonaws.com
docker build -t nrcan-gdalcubes:latest .
docker tag nrcan-gdalcubes:latest <flood-mapping-AWS-ECR-docker-tag>
docker push <flood-mapping-AWS-ECR-docker-tag>
```

### DEPLOYMENT
Update Task Definiton name and floodmapping container name in db/flood-mapping.json to reflect AWS infrastructure.
``` bash
aws dynamodb put-item --table-name <Process-Table-Name> --item file://db/flood-mapping.json
```
