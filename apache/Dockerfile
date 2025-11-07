FROM httpd:2.4

# Copy our SSL/proxy site config into Apache's conf directory
COPY secure-proxy.conf /usr/local/apache2/conf/extra/secure-proxy.conf

# Make sure the main httpd.conf includes our extra config
RUN echo "Include conf/extra/secure-proxy.conf" >> /usr/local/apache2/conf/httpd.conf

# Expose HTTPS port (httpd image already exposes 80)
EXPOSE 443
# Use default CMD from base image (httpd-foreground)
