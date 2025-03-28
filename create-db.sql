CREATE DATABASE IF NOT EXISTS $ENV_WORDPRESS_DATABASE;
CREATE USER IF NOT EXISTS "$ENV_WORDPRESS_DATABASE_USER"@"localhost" IDENTIFIED BY "$ENV_WORDPRESS_DATABASE_USER_PASSWORD";
GRANT ALL PRIVILEGES ON $ENV_WORDPRESS_DATABASE.* TO "$ENV_WORDPRESS_DATABASE_USER"@"localhost";
FLUSH PRIVILEGES;
