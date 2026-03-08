FROM node:18-alpine

# Use an unprivileged user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create app directory and set ownership
WORKDIR /usr/src/app
RUN mkdir -p /usr/src/app/uploads && chown -R appuser:appgroup /usr/src/app

# Only copy package dependencies first to cache npm install layer
COPY package*.json ./
RUN npm install --production

# Copy the rest of the application files
COPY . .

# Adjust permissions on copied files
RUN chown -R appuser:appgroup /usr/src/app

# Switch mapping to the secure user
USER appuser

EXPOSE 3000

# Start command
CMD [ "npm", "start" ]
