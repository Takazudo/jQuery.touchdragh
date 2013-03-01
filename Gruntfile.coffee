module.exports = (grunt) ->
  
  utils = (require './gruntcomponents/misc/commonutils')(grunt)
  grunt.task.loadTasks 'gruntcomponents/tasks'
  grunt.task.loadNpmTasks 'grunt-contrib-watch'
  grunt.task.loadNpmTasks 'grunt-contrib-concat'
  grunt.task.loadNpmTasks 'grunt-contrib-uglify'

  grunt.initConfig

    pkg: grunt.file.readJSON('package.json')

    growl:

      ok:
        title: 'COMPLETE!!'
        msg: '＼(^o^)／'

    coffee:

      touchdrag:
        options:
          bare: true
        files: [ 'jquery.touchdrag.coffee' ]
        dest: 'jquery.touchdrag.js'

    concat:

      banner:
        options:
          banner: """
/*! <%= pkg.name %> (<%= pkg.repository.url %>)
 * lastupdate: <%= grunt.template.today("yyyy-mm-dd") %>
 * version: <%= pkg.version %>
 * author: <%= pkg.author %>
 * License: MIT */\n
"""
        src: [ '<%= coffee.touchdrag.dest %>' ]
        dest: '<%= coffee.touchdrag.dest %>'
        
    uglify:

      options:
        preverveComments: 'some'
      touchdrag:
        src: '<%= concat.banner.dest %>'
        dest: 'jquery.touchdrag.min.js'

    watch:

      touchdrag:
        files: '<%= coffee.touchdrag.files %>'
        tasks: [
          'default'
        ]


  grunt.event.on 'coffee.error', (msg) ->
    utils.growl 'ERROR!!', msg

  grunt.registerTask 'default', [
    'coffee'
    'concat'
    'uglify'
    'growl:ok'
  ]

