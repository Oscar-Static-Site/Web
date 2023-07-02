FROM hugomods/hugo AS build
COPY . /src

FROM nginx  
COPY --from=build /src/public /usr/share/nginx/html

