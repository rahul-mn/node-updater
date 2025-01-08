FROM alpine:latest

# Install docker, curl, and cron
RUN apk add --no-cache docker-cli curl busybox-suid

# # Add user barbosa
# RUN adduser -D barbosa

# Create a directory for the script
RUN mkdir /app
WORKDIR /app

# # Change ownership of /app to barbosa
# RUN chown -R barbosa:barbosa /app

# Copy the shell script
COPY script.sh /app/

# Make the script executable
RUN chmod +x /app/script.sh

# Create a log file
RUN touch /app/cron.log

# Add cron job for the root user
RUN echo "*/3 * * * * /bin/sh /app/script.sh >> /app/cron.log 2>&1" > /etc/crontabs/root

# Start crond in the foreground                                              
CMD ["crond", "-f", "-d", "8"]
