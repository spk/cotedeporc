# cotedeporc

## Quotes api with Grape and Sequel

### Run

```
bundle install
bundle exec rackup
```

### Add a quote

```
curl -v -XPOST http://127.0.0.1:9292/quotes \
  -d 'quote[topic]=youpi' -d 'quote[body]=youpi !!!'
```

### List quotes

```
curl -v http://127.0.0.1:9292/quotes
```

## License

The MIT License

Copyright (c) 2012-2019 Laurent Arnoud <laurent@spkdev.net>
