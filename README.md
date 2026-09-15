#  Курсовая работа на профессии "DevOps-инженер с нуля" - Розаев А.Ю.

Содержание
==========
* [Задача](#Задача)
* [Инфраструктура](#Инфраструктура)
    * [Сайт](#Сайт)
    * [Мониторинг](#Мониторинг)
    * [Логи](#Логи)
    * [Сеть](#Сеть)
    * [Резервное копирование](#Резервное-копирование)
    * [Дополнительно](#Дополнительно)
* [Выполнение работы](#Выполнение-работы)
* [Процедура развёртывания проекта](#Процедура-развёртывания-проекта)
    * [Подготовка и запуск Terraform](#Подготовка-и-запуск-Terraform)
    * [Подготовка и запуск Ansible](#Подготовка-и-запуск-Ansible)
    * [Проверка корректности работы сервисов](#Проверка-корректности-работы-сервисов)
    
---------
## Задача
Согласно условию задачи разработана и развернута отказоустойчивая инфраструктура для сайта, включающая мониторинг, сбор логов и резервное копирование основных данных. Инфраструктура размещена в [Yandex Cloud](https://cloud.yandex.com/).

---

## Инфраструктура
Для развёртки инфраструктуры использован Terraform и Ansible.

- с помощью [Terraform](https://github.com/expgt/net-fops-cw/blob/main/netcw/terraform) произведен provisioning инфраструктуры

![Terraform](https://github.com/expgt/net-fops-cw/blob/main/terraform.png)

- с помощью [Ansible](https://github.com/expgt/net-fops-cw/blob/main/netcw/ansible) произведен deployment необходимого ПО

![Ansible](https://github.com/expgt/net-fops-cw/blob/main/ansible.png)

---

### Сайт
Созданы две ВМ в разных зонах (ru-central1-a и ru-central1-b), на них установлен сервер nginx.

Создана Instance Group, с условием масштабирования: минимальное количество ВМ на зону — 1, максимальный размер группы — 3.

Создана Backend Group, backends настроен на Instance Group. Настроен healthcheck на корень (/) и порт 80, протокол HTTP.

Создан HTTP router. Указан путь — / и ранее созданная backend group.

Создан Application load balancer для распределения трафика на веб-сервера. Указан HTTP router, задан listener тип auto, порт 80.

![Alb](https://github.com/expgt/net-fops-cw/blob/main/alb.png)
![Web_health](https://github.com/expgt/net-fops-cw/blob/main/web_health.png)

Сайт протестирован запросом
`curl -v <публичный IP балансера>:80`

![Curl](https://github.com/expgt/net-fops-cw/blob/main/curl.png)

Для сайта использован набор статичных файлов

![Site](https://github.com/expgt/net-fops-cw/blob/main/site.png)

---

### Мониторинг
Создана отдельная ВМ, развернут контейнер Prometheus. На каждую ВМ из веб-серверов установлен Node Exporter и Nginx Log Exporter. Prometheus настроен на сбор метрик с этих exporter.

Создана отдельная ВМ, развернут контейнер Grafana. Настроено взаимодействие с Prometheus. Настроены дешборды с отображением метрик для Utilization, Saturation, Errors для CPU, RAM, диски, сеть, http_response_count_total, http_response_size_bytes. Добавлены необходимые tresholds на соответствующие графики.

![Grafana](https://github.com/expgt/net-fops-cw/blob/main/grafana_dashb.png)

---

### Логи
Создана отдельная ВМ, развернут контейнер Elasticsearch. На ВМ веб-серверов установлен filebeat, настроена отправка access.log, error.log nginx в Elasticsearch.

Создана отдельная ВМ, развернут контейнер Kibana, сконфигурировано соединение с Elasticsearch.

![Kibana_nginx](https://github.com/expgt/net-fops-cw/blob/main/kibana_nginx.png)

---

### Сеть
Развернута VPC. 

![VPC](https://github.com/expgt/net-fops-cw/blob/main/vpc.png)
![Map_infra](https://github.com/expgt/net-fops-cw/blob/main/map_infra.png)

Сервера web, Prometheus, Elasticsearch размещены в приватные подсети.

![VM](https://github.com/expgt/net-fops-cw/blob/main/vm.png)

Сервера Grafana, Kibana, application load balancer размещены в публичную подсеть.

![IP_pub](https://github.com/expgt/net-fops-cw/blob/main/ip_pub.png)

Настроены Security Groups соответствующих сервисов на входящий трафик только к нужным портам.

![Sec_gr](https://github.com/expgt/net-fops-cw/blob/main/sec_gr.png)

Настроена ВМ с публичным адресом - bastion host, с открытым только одним портом 22 — ssh. Все security groups настроены на разрешение входящего ssh из этой security group.

---

### Резервное копирование
Настроено создание snapshot дисков всех ВМ. Время жизни snaphot - неделя. Само создание snaphot настроено на ежедневное копирование.

![Snap](https://github.com/expgt/net-fops-cw/blob/main/snap.png)

Поскольку веб-ноды являются взаимозаменяемыми и не хранят уникальных пользовательских или системных данных (stateless), классическое резервное копирование дисков виртуальных машин не производится. Архитектура проекта рассчитана на то, что любой узел Instance Group может быть безвозвратно удален или пересоздан в любой момент времени без потери работоспособности сервиса из шаблона Instance Template и повторным deployment Ansible.

---

### Дополнительно

1. Для Prometheus реализован альтернативный способ хранения данных — в базе данных PpostgreSQL. Использован Yandex Managed Service for PostgreSQL, развернут кластер из двух нод с автоматическим failover. Для настройки отправки данных из Prometheus в новую БД использован адаптер Telegraf (предложенный вариант https://github.com/CrunchyData/postgresql-prometheus-adapter устарел и не поддерживается Yandex Managed Service for PostgreSQL).

![HA_PG_cluster](https://github.com/expgt/net-fops-cw/blob/main/ha_cluster.png)

2. Вместо target group и конкретных ВМ, создана Instance Group, для которой настроены следующие правила автоматического горизонтального масштабирования: минимальное количество ВМ на зону — 1, максимальный размер группы — 3. Настройки target group в закомментированном виде также сохранены в конфигурации terraform.


3. В Grafana добавлены оповещения с помощью Grafana alerts. В ВМ к Prometheus установлен контейнер Alertmanager, настроено оповещение в мессенджер.

4. В Elasticsearch добавлен мониторинг логов самого себя, Kibana, Prometheus, Grafana через filebeat.

![Kibana_infra](https://github.com/expgt/net-fops-cw/blob/main/kibana_infra.png)

5. С помощью Yandex Certificate Manager настроен выпуск сертификата для сайта. Перенастроена работа балансера на HTTPS, который нацелен на HTTP веб-серверов.
Данные настройки сохранены в конфигурации terraform в закомментированном виде и могут быть применены после регистрации доменного имени.

---

## Выполнение работы

⚠️ Разворачивание сервисов выполнено с помощью docker контейнеров, основанных на официальных образах.

---

## Процедура развёртывания проекта

### Подготовка и запуск Terraform

1. Создать Авторизованный ключ (JSON) для сервисного аккаунта в Yandex Cloud 
```bash
yc iam key create \
  --service-account-name <ИМЯ_СЕРВИСНОГО_АККАУНТА> \
  --output authorized_key.json
```
ключ должен располагаться в домашнем каталоге ~/.authorized_key.json

2. Перейти в каталог terraform:
```bash
cd netcw/terraform
```
3. Добавить значение полей в файл terraform.tfvars:
```bash
nano terraform.tfvars
```
- cloud_id = "<ID папки облака в yandex cloud>"
- folder_id = "<ID папки каталога в yandex cloud>"
- service_account = "<Имя сервисного аккаунта для авторизации в yandex cloud>"
- ubuntu_user = "<Имя пользователя, которого надо создать при конфигурации ВМ>"
- ssh_public_key = "<Публичный ключ, который нужно добавить на созданные ВМ, для доступа к ним>"
- pg_user     = "<Имя пользователя PostgreSQL, который будет создан при конфигурации БД>"
- pg_password = "<Пароль PostgreSQL>"
- pg_database = "<Имя БД PostgreSQL>"

4. Выполнить:
- подготовку рабочего каталога к работе с Terraform
```bash
terraform init
```
- проверку кода на соответствие единому каноническому стилю Terraform
```bash
terraform fmt -check -recursive
```
- проверку синтаксической и логической корректности конфигурационных файлов
```bash
terraform validate
```
- предварительный просмотр всех настроек, которые будут произведены при создании инфраструктуры
```bash
terraform plan
```
- provisioning
```bash
terraform apply
```
- просмотр публичных IP Bastion, Kibana, Grafana
```bash
terraform output
```

5. После завершения конфигурации проверить создание файла инвентаря Ansible - /netcw/ansible/hosts.ini

---

### Подготовка и запуск Ansible

1. Перейти в каталог ansible:
```bash
cd netcw/ansible
```
2. Добавить значение полей в файл /group_vars/all/vault.yml:
```bash
nano /group_vars/all/vault.yml
```
- telegram_chat_id: <ID чата telegram>
- telegram_bot_token: "<Токен бота telegram>"
- grafana_admin_user: "<Имя пользователя Grafana, который будет создан при конфигурации>"
- grafana_admin_password: "<Пароль пользователя Grafana>"

3. Выполнить:
- шифрование конфиденциальных данных проекта 
```bash
ansible-vault encrypt group_vars/all/vault.yml
```
- задать пароль

4. Выполнить:
- проверку доступности созданных ВМ для Bastion, Kibana, Grafana
```bash
ansible all -m ping
```
- проверку синтаксиса плейбука
```bash
ansible-playbook site.yml --syntax-check
```
- deployment
```bash
ansible-playbook site.yml
```
---

### Проверка корректности работы сервисов

- проверить доступность сервисов ALB, Kibana, Grafana
```bash
curl http://<ALB_IP:80>
```
```bash
curl http://<Kibana_IP:5601>
```
```bash
curl http://<Grafana_IP:3000>
```
- проверить targets с хоста Prometheus
```bash
curl -s http://localhost:9090/api/v1/targets
```
- проверить в веб-интерфейсе отображение Grafana dashboard
- проверить в веб-интерфейсе наличие nginx-логов в Kibana
- проверить через [Консоль управления yandex cloud](https://console.yandex.cloud) состояние snapshot schedule


