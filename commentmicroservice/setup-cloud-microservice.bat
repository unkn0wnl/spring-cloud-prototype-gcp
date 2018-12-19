@echo off

REM set global variables:
CALL ../set-variables

SET microservice=comment-microservice
SET jarfile=build/libs/commentmicroservice-0.0.1-SNAPSHOT.jar

ECHO ### create service account and secret ###
CALL gcloud iam service-accounts create %microservice%
CALL gcloud projects add-iam-policy-binding %project% --member serviceAccount:%microservice%@%project%.iam.gserviceaccount.com --role roles/pubsub.admin
CALL gcloud projects add-iam-policy-binding %project% --member serviceAccount:%microservice%@%project%.iam.gserviceaccount.com --role roles/datastore.owner
CALL gcloud iam service-accounts keys create --iam-account %microservice%@%project%.iam.gserviceaccount.com %microservice%-credentials.json
CALL kubectl create secret generic comment-secret --from-file=credentials.json=%microservice%-credentials.json

REM build
CALL gradlew build

REM create docker file
CALL docker build -t eu.gcr.io/%project%/%microservice%:latest --build-arg JAR_FILE=%jarfile% .

REM push docker file
CALL gcloud docker -- push eu.gcr.io/%project%/%microservice%:latest

REM generate kubernetes files from templates
IF NOT EXIST "kubernetes\generated\" mkdir kubernetes\generated\
COPY kubernetes\template\deployment.yaml kubernetes\generated\
COPY kubernetes\template\service.yaml kubernetes\generated\
REM replace template variables
powershell -Command "(gc kubernetes\generated\deployment.yaml) -replace 'PROJECT_NAME', '%project%' | Out-File kubernetes\generated\deployment.yaml"

REM apply kubernetes components and services
ECHO apply kubernetes components and services
CALL kubectl apply -f kubernetes/generated/
CALL kubectl patch deployment %microservice% -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"modified\":\"%date%_%time::=-%\"}}}}}"