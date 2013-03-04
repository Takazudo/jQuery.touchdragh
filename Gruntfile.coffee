module.exports = (grunt) ->
  
  utils = (require './gruntcomponents/misc/commonutils')(grunt)
  grunt.task.loadTasks 'gruntcomponents/tasks'
  grunt.task.loadNpmTasks 'grunt-contrib-coffee'
  grunt.task.loadNpmTasks 'grunt-contrib-watch'
  grunt.task.loadNpmTasks 'grunt-contrib-concat'
  grunt.task.loadNpmTasks 'grunt-contrib-uglify'

  grunt.initConfig

    pkg: grunt.file.readJSON('package.json')
    banner: """
/*! <%= pkg.name %> (<%= pkg.repository.url %>)
 * lastupdate: <%= grunt.template.today("yyyy-mm-dd") %>
 * version: <%= pkg.version %>
 * author: <%= pkg.author %>
 * License: MIT */

"""

    growl:

      ok:
        title: 'COMPLETE!!'
        msg: '＼(^o^)／'

    coffee:

      touchdragh:
        src: [ 'jquery.touchdragh.coffee' ]
        dest: 'jquery.touchdragh.js'

    concat:

      banner:
        options:
          banner: '<%= banner %>'
        src: [ '<%= coffee.touchdragh.dest %>' ]
        dest: '<%= coffee.touchdragh.dest %>'
        
    uglify:

      options:
        banner: '<%= banner %>'
      touchdragh:
        src: '<%= concat.banner.dest %>'
        dest: 'jquery.touchdragh.min.js'

    watch:

      touchdragh:
        files: '<%= coffee.touchdragh.files %>'
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

