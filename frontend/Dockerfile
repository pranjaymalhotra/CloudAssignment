FROM nginx:alpine

# Copy the comprehensive demo UI as index.html to nginx
COPY comprehensive-demo.html /usr/share/nginx/html/index.html

# Expose port 80
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
