SHELL := /bin/bash

.PHONY: docs backup restore

menu:
	@perl -ne 'printf("%10s: %s\n","$$1","$$2") if m{^([\w+-]+):[^#]+#\s(.+)$$}' Makefile

all: # Run everything except build
	$(MAKE) fmt
	$(MAKE) lint
	$(MAKE) docs

fmt: # Format drone fmt
	@echo
	drone exec --pipeline $@

lint: # Run drone lint
	@echo
	drone exec --pipeline $@

docs: # Build docs
	@echo
	drone exec --pipeline $@

edit:
	docker-compose -f docker-compose.docs.yml pull docs
	docker-compose -f docker-compose.docs.yml run --rm docs

logs: # Logs for docker-compose
	docker-compose logs -f

up: # Run home container with docker-compose
	$(RENEW) docker-compose up -d

down: # Shut down home container
	docker-compose down

restart: # Restart home container
	$(RENEW) docker-compose restart

recreate: # Recreate home container
	-$(MAKE) down
	$(MAKE) up

backup: # Backup wordpress content
	docker-compose stop
	docker cp $(shell docker-compose ps -q wordpress):/bitnami/wordpress backup/
	docker cp $(shell docker-compose ps -q mariadb):/bitnami/mariadb backup/
	kitt up
	cd backup && git add . && git commit -m "backup: $(date)" && git push

restore: # Restore wordpress content
	cd restore && $(MAKE) -f ../Makefile restore-inner

restore-inner:
	docker-compose down -v
	kitt up
	sleep 20
	docker-compose stop
	sudo perl -pe 's{mariadb:3306}{mariadb-restore:3306}' -i ../backup/wordpress/wp-config.php
	$(MAKE) -f ../Makefile restore-inner-inner
	sudo perl -pe 's{mariadb-restore:3306}{mariadb:3306}' -i ../backup/wordpress/wp-config.php
	kitt up

restore-inner-inner:
	docker cp ../backup/mariadb $(shell docker-compose ps -q mariadb-restore):/bitnami/
	docker cp ../backup/wordpress $(shell docker-compose ps -q wordpress-restore):/bitnami/

restore-main:
	docker-compose stop
	docker cp backup/mariadb $(shell docker-compose ps -q mariadb):/bitnami/
	docker cp backup/wordpress $(shell docker-compose ps -q wordpress):/bitnami/
	kitt up
