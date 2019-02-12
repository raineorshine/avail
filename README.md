# avail

Smart, text-based calendar availability reporter.

## Install

Not published (yet)

<!--```sh
$ npm install --global ???
```-->

Copy `config.example.json` to `config.json` and enter Google API details.

## Web Server

```
npm run start
open http://localhost:8082
open http://localhost:8082/TEST@TEST.COM
open http://localhost:8082/TEST@TEST.COM/EVENT_ID
```

## CLI

```sh
$ events.json < avail
Mon 7/10 9am-5pm
Tue 7/11 9am-2:30pm
Tue 7/11 3:30-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9-11am
Fri 7/14 2-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm
```

## License

ISC © [Raine Revere](https://github.com/raineorshine)
