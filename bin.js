#! /usr/bin/env node
const com = require('commander')
const pkg = require('./package.json')
const { printFreeBlocks } = require('./find-free-blocks.js')
const { readFile } = require('fs')

const extendedHelp = `

${pkg.description}

Example:
$ avail < events.json`

const program = com
  .version(pkg.version)
  .arguments('<file>')
  .usage(extendedHelp)
  .parse(process.argv)

const input = program.args[0]
  // filename from command line arguments
  ? new Promise((resolve, reject) => {
    readFile(program.args[0], 'utf-8', (err, data) => {
      if(err) { return reject(err) }
      resolve(data)
    })
  })
  // stdin
  : require('get-stdin-promise')

input
  .then(source => {
    if (source.trim()) {
      console.log(printFreeBlocks(JSON.parse(source)))
    }
    else {
      program.help()
    }
  })
  .catch(console.error)
