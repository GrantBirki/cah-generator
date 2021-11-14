multi-card-output:
	@echo "\033[0;34m[i] Generating a multi-card PDF file with all cards\033[0m"
	@echo "\033[0;34m[#] Killing old docker processes\033[0m"
	docker-compose rm -fs

	@echo "\033[0;34m[#] Running docker containers\033[0m"
	docker-compose up --build multi-card
	docker-compose rm -fs
