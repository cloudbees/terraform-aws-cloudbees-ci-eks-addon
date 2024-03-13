FROM osixia/openldap:1.5.0

ENV DEBIAN_FRONTEND=noninteractive \
    LDAP_ORGANISATION="Acme Org" \
    LDAP_DOMAIN="acme.org" \
    LDAP_ADMIN_PASSWORD="admin" \
    LDAP_BASE_DN="dc=acme,dc=org" \
    IMAGE_ROOT_PATH=.docker/openldap

COPY ${IMAGE_ROOT_PATH}/data.ldif /container/service/slapd/assets/config/bootstrap/ldif/50-bootstrap.ldif