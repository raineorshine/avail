const chai = require('chai')
const { printFreeBlocks } = require('../find-free-blocks.js')
const should = chai.should()

const sec = 1000
const min = 60*sec
const hr = 60*min
const day = 24*hr
const daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

describe('avail', () => {

  it('should find all free blocks with default settings', () => {

    const events = [
      {
        "summary": "A",
        "start": { "dateTime": "2017-04-04T15:30:00-06:00" },
        "end": { "dateTime": "2017-04-04T17:30:00-06:00" }
      },
      {
        "summary": "B",
        "start": { "dateTime": "2017-07-11T14:30:00-06:00" },
        "end": { "dateTime": "2017-07-11T15:30:00-06:00" }
      },
      {
        "summary": "C",
        "start": { "dateTime": "2017-07-14T11:00:00-06:00" },
        "end": { "dateTime": "2017-07-14T14:00:00-06:00" }
      }
    ]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime()
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9am-2:30pm
Tue 7/11 3:30-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9-11am
Fri 7/14 2-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should exclude blocks smaller than the minimum block size', () => {

    const events = [
      {
        "summary": "A",
        "start": { "dateTime": "2017-07-11T10:30:00-06:00" },
        "end": { "dateTime": "2017-07-11T11:30:00-06:00" }
      },
      {
        "summary": "B",
        "start": { "dateTime": "2017-07-11T11:45:00-06:00" },
        "end": { "dateTime": "2017-07-11T12:45:00-06:00" }
      }
    ]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9-10:30am
Tue 7/11 12:45-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should exclude blocks smaller than the minimum block size at the beginning of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-10T09:15:00-06:00" },
      "end": { "dateTime": "2017-07-10T10:15:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 10:15am-5pm
Tue 7/11 9am-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should exclude blocks smaller than the minimum block size at the end of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-16T16:15:00-06:00" },
      "end": { "dateTime": "2017-07-16T16:45:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9am-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-4:15pm`)
  })

  it('should handle events overlapping the beginning of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-11T08:00:00-06:00" },
      "end": { "dateTime": "2017-07-11T10:00:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 10am-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should handle events overlapping the end of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-11T15:00:00-06:00" },
      "end": { "dateTime": "2017-07-11T19:00:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9am-3pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })


  it('should handle events adjacent to the beginning of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-11T09:00:00-06:00" },
      "end": { "dateTime": "2017-07-11T10:00:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 10am-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should handle events adjacent to the end of the day', () => {

    const events = [{
      "summary": "A",
      "start": { "dateTime": "2017-07-11T15:00:00-06:00" },
      "end": { "dateTime": "2017-07-11T17:00:00-06:00" }
    }]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime(),
      minBlockSize: 30*min
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9am-3pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

  it('should handle overlapping events', () => {

    const events = [
      {
        "summary": "A",
        "start": { "dateTime": "2017-07-11T10:00:00-06:00" },
        "end": { "dateTime": "2017-07-11T11:30:00-06:00" }
      },
      {
        "summary": "B",
        "start": { "dateTime": "2017-07-11T11:00:00-06:00" },
        "end": { "dateTime": "2017-07-11T12:30:00-06:00" }
      }
    ]

    printFreeBlocks(events, {
      timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime()
    })
      .should.equal(`Mon 7/10 9am-5pm
Tue 7/11 9-10am
Tue 7/11 12:30-5pm
Wed 7/12 9am-5pm
Thu 7/13 9am-5pm
Fri 7/14 9am-5pm
Sat 7/15 9am-5pm
Sun 7/16 9am-5pm`)
  })

})
