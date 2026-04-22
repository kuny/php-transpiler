COMPOSE = docker compose
TRANSPILE_SERVICE = transpiler
COMPOSER_SERVICE = composer

.PHONY: help install image doctor transpile fix build rebuild clean check shell-racket shell-composer

help:
	@echo "make install        - composer install"
	@echo "make image          - transpiler イメージを再ビルド"
	@echo "make doctor         - Racket コンテナの arch を確認"
	@echo "make transpile      - sexp/ から build/ に PHP を生成"
	@echo "make fix            - build/ の PHP を php-cs-fixer で整形"
	@echo "make build          - transpile + fix"
	@echo "make rebuild        - clean + build"
	@echo "make clean          - build/ 配下を削除"
	@echo "make check          - php-cs-fixer dry-run --diff"
	@echo "make shell-racket   - Racket コンテナでシェル"
	@echo "make shell-composer - Composer コンテナでシェル"

install:
	$(COMPOSE) run --rm $(COMPOSER_SERVICE) install

image:
	$(COMPOSE) build --no-cache --pull $(TRANSPILE_SERVICE)

doctor:
	$(COMPOSE) run --rm --entrypoint sh $(TRANSPILE_SERVICE) -lc "uname -m && racket -e '(displayln (system-type '\''machine))' && racket -v"

transpile:
	$(COMPOSE) run --rm $(TRANSPILE_SERVICE)

fix:
	$(COMPOSE) run --rm $(COMPOSER_SERVICE) exec php-cs-fixer fix

build: transpile fix

rebuild: clean build

clean:
	rm -rf build/*

check:
	$(COMPOSE) run --rm $(COMPOSER_SERVICE) exec php-cs-fixer fix --dry-run --diff

shell-racket:
	$(COMPOSE) run --rm --entrypoint sh $(TRANSPILE_SERVICE)

shell-composer:
	$(COMPOSE) run --rm $(COMPOSER_SERVICE) sh
