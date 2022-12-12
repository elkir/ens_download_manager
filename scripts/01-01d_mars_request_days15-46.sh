cat ../mars_requests/mars_request_01d_days15-46.req | 
sed "s/retrieve/list/" | 
# sed '3 i output = cost,' | 
mars -o mars_01d_days15-46.list