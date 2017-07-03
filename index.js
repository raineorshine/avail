const express  = require('express')
const session = require('express-session')
const config = require('./config')
const gcal = require('google-calendar')

/*
  ===========================================================================
            Setup express + passportjs server for authentication
  ===========================================================================
*/

const app = express()
const passport = require('passport')
const GoogleStrategy = require('passport-google-oauth').OAuth2Strategy

app.use(session({ secret: config.sessionSecret }))
app.use(passport.initialize())
app.listen(8082)

passport.use(new GoogleStrategy({
    clientID: config.googleClientId,
    clientSecret: config.googleClientSecret,
    callbackURL: "http://localhost:8082/auth/callback",
    scope: ['openid', 'email', 'https://www.googleapis.com/auth/calendar']
  },
  (accessToken, refreshToken, profile, done) => {
    profile.accessToken = accessToken
    return done(null, profile)
  }
))

app.get('/auth',
  passport.authenticate('google', { session: false }))

app.get('/auth/callback',
  passport.authenticate('google', { session: false, failureRedirect: '/login' }),
  (req, res) => {
    req.session.access_token = req.user.accessToken
    res.redirect('/')
  })


/*
  ===========================================================================
                               Google Calendar
  ===========================================================================
*/

app.all('/', (req, res) => {

  if(!req.session.access_token) return res.redirect('/auth')

  //Create an instance from accessToken
  const accessToken = req.session.access_token

  gcal(accessToken).calendarList.list((err, data) => {
    if(err) return res.send(500,err)
    return res.send(data)
  })
})

app.all('/:calendarId', (req, res) => {

  if(!req.session.access_token) return res.redirect('/auth')

  //Create an instance from accessToken
  const accessToken     = req.session.access_token
  const calendarId      = req.params.calendarId

  let items = []

  gcal(accessToken).events.list(calendarId, {timeMin: '2017-04-01T19:00:00.000Z', maxResults: 10, singleEvents: true}, (err, data) => {
    if(err) return res.send(500,err)

    items = items.concat(data.items)
    if(data.nextPageToken){
      gcal(accessToken).events.list(calendarId, {timeMin: '2017-04-01T19:00:00.000Z', maxResults: 10,singleEvents: true, pageToken:data.nextPageToken}, (err, data) => {
        items = items.concat(data.items)
        return res.send(items)
      })
    }
  })
})


app.all('/:calendarId/:eventId', (req, res) => {

  if(!req.session.access_token) return res.redirect('/auth')

  //Create an instance from accessToken
  const accessToken     = req.session.access_token
  const calendarId      = req.params.calendarId
  const eventId         = req.params.eventId

  gcal(accessToken).events.get(calendarId, eventId, (err, data) => {
    if(err) return res.send(500,err)
    return res.send(data)
  })
})
