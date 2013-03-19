package('cool','1.0')
C.directory 'src'
C.module.cool()
    :when 'win32': add 'wutils.c'
    :otherwise 'unix': add 'putils.c'
