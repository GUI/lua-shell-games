FROM openresty/openresty:1.15.8.1-4-centos

# Build dependencies.
RUN yum -y install make

# Dependencies for the release process.
RUN yum -y install git zip

ENV LUA_PATH /root/.luarocks/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;;
ENV LUA_CPATH /usr/local/openresty/luajit/lib/lua/5.1/?.so;;

RUN mkdir /app
WORKDIR /app

COPY Makefile /app/Makefile
RUN make install-test-deps-yum
RUN make install-test-deps

COPY . /app
