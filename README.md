# cotedeporc

## Quotes api with Grape and Sequel

### Run

	bundle install
	thin start

### Add a quote

	curl -v -XPOST http://localhost:3000/quotes \
		-d 'quote[topic]=youpi' -d 'quote[body]=youpi !!!'
