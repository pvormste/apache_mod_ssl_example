FROM httpd:2.4

# Copy the mTLS upstream config
COPY mtls-upstream.conf /usr/local/apache2/conf/extra/mtls-upstream.conf

# Include the config
RUN echo "Include conf/extra/mtls-upstream.conf" >> /usr/local/apache2/conf/httpd.conf

# Expose HTTPS port
EXPOSE 443
