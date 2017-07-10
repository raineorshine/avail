const chai = require('chai')
const { printFreeBlocks } = require('../find-free-blocks.js')
const should = chai.should()

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

describe('avail', () => {
  it('should find all free blocks with default settings', () => {
    printFreeBlocks(events, { timeMin: (new Date('2017-07-10T03:00:00.000Z')).getTime() })
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
})
