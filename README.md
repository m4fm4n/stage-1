Дипломный проект для SkillFactory
---

Этап первый.

Описать инфраструктру через Terraform.

---

Инфраструктура содержит 3 ВМ: два сервера под kubernetes и сервер для инструментов мониторинга, логгирования и сборок контейнеров.

Автоматизированна установка через terraform и ansible.
 
---

Чтобы запустить этот проект, необходимо:

1. Иметь установленный Terraform>=1.3.9

2. Иметь установленный Ansible>=7

3. Зарегистрироваться в Яндекс Облако

3.1. Получить свой OAuth token

4. Зарегистрироваться в GitLab

4.1. Создать проект stage-2

4.2. Создать в "Settings / CI/CD" регистрационный токен для gitlab-runner

4.3. Отключить Shared runners

---

В main.tf ввести свои регистрационные данные из Яндекс облака:

```
provider "yandex" {
  token     = "<OAuth_token>"
  cloud_id  = "<cloud_id>"
  folder_id = "<folder_id>"
  zone      = "ru-central1-a"
}
```

В variables.tf изменить путь до необходимого публичного и приватного ssh-ключей(если они имееют другое название):

```
  default     = {
    user        = "ubuntu"
    private_key = "~/.ssh/id_rsa"
    pub_key     = "~/.ssh/id_rsa.pub"
  }
```

В gitlab-run-token.yml добавить регистрационный токен из пункта требований 4.2

```
gitlab_run_token: "<runner_token>"
```

Скрипт ansibe-run.sh сделать исполняемым:

```
sudo chmod +x ansibe-run.sh
```

Запустить инициализацию Terraform:

```
terraform init
```

Запустить развёртку Terraform:

```
terraform apply -auto-approve
```
