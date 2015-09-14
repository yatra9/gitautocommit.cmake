
if (NOT DEFINED prebuild AND NOT DEFINED postbuild)
  # included

  set(GIT_AUTOCOMMIT_SCRIPT ${CMAKE_CURRENT_LIST_FILE}
     CACHE STRING "CMake script")

  macro(GIT_AUTOCOMMIT target)
    find_package(Git QUIET)
    if(NOT GIT_FOUND)
      # TODO: fixme
      message(FATAL_ERROR "git not found: ${GIT_EXECUTABLE}")
    endif()
    
    set(GIT_AUTOCOMMIT_AUTHORTEMPLATE "automatic commit (@CONF_AUTHOR_NAME@) <@CONF_AUTHOR_EMAIL@>"
        CACHE STRING "author of commit message (use @CONF_AUTHOR_NAME@ and @CONF_AUTHOR_EMAIL@)")
    set(GIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM 0
        CACHE STRING "start number of auto-generated branch name")
    set(GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE "autogen/@CURRENT_BRANCH_NAME@/@BRANCH_N@"
        CACHE STRING "auto-generated branch name template (use @CURRENT_BRANCH_NAME@ and @BRANCH_N@)")
    set(GIT_AUTOCOMMIT_COMMIT_MESSAGE "auto commit"
        CACHE STRING "commit message")
    set(GIT_AUTOCOMMIT_GIT_REPOSITORY "${CMAKE_CURRENT_SOURCE_DIR}"
        CACHE STRING "git repository")
    set(GIT_AUTOCOMMIT_GITEXE "${GIT_EXECUTABLE}"
        CACHE STRING "/path/to/git")
    set(GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX ""
       CACHE STRING "regex expression that maches auto-generated brancehs (or empty string for automatic guess)")
    set(GIT_AUTOCOMMIT_MESSAGE_PREFIX "git-autocommit: "
       CACHE STRING "message prefix")
    mark_as_advanced(GIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM
                     GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX
                     GIT_AUTOCOMMIT_MESSAGE_PREFIX
                     GIT_AUTOCOMMIT_SCRIPT
                     GIT_AUTOCOMMIT_GITEXE)


    set(prebuild_target "gitautocommit_prebuild_${target}")
    add_custom_target(${prebuild_target}
                       COMMAND ${CMAKE_COMMAND} -Dprebuild=ON
                           -DGIT_AUTOCOMMIT_GITEXE=${GIT_AUTOCOMMIT_GITEXE}
                           -DGIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM=${GIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM}
                           -DGIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE=${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE}
                           -DGIT_AUTOCOMMIT_COMMIT_MESSAGE=${GIT_AUTOCOMMIT_COMMIT_MESSAGE}
                           -DGIT_AUTOCOMMIT_AUTHORTEMPLATE=${GIT_AUTOCOMMIT_AUTHORTEMPLATE}
                           -DGIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX=${GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX}
                           -DGIT_AUTOCOMMIT_MESSAGE_PREFIX=${GIT_AUTOCOMMIT_MESSAGE_PREFIX}
                           -P ${GIT_AUTOCOMMIT_SCRIPT}
                       COMMENT "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}check git status on ${GIT_AUTOCOMMIT_GIT_REPOSITORY}"
                       WORKING_DIRECTORY ${GIT_AUTOCOMMIT_GIT_REPOSITORY}
                       VERBATIM)
                       
    set_target_properties(${prebuild_target} PROPERTIES EchoString "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}check git status on ${GIT_AUTOCOMMIT_GIT_REPOSITORY}")
    add_dependencies(${target} ${prebuild_target})

  endmacro()

elseif(DEFINED prebuild)
  # must be set ${GIT_AUTOCOMMIT_GITEXE} ${GIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM} ${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE} ${GIT_AUTOCOMMIT_COMMIT_MESSAGE}
  # optional ${GIT_AUTOCOMMIT_AUTHORTEMPLATE} ${GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX} ${GIT_AUTOCOMMIT_MESSAGE_PREFIX}

  if (NOT DEFINED GIT_AUTOCOMMIT_MESSAGE_PREFIX OR GIT_AUTOCOMMIT_MESSAGE_PREFIX STREQUAL "")
    set(GIT_AUTOCOMMIT_MESSAGE_PREFIX "git-autocommit: ")
  endif()
  
  macro(execute_git)
    execute_process(COMMAND ${GIT_AUTOCOMMIT_GITEXE} ${ARGN}
                    RESULT_VARIABLE comres
                    OUTPUT_VARIABLE comout0
                    ERROR_VARIABLE comerr0)
    string(STRIP "${comout0}" comout)
    string(STRIP "${comerr0}" comerr)
  endmacro()

  function(is_autogen_branch branchname result)
    if (DEFINED GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX AND NOT GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX STREQUAL "")
      set(matchstring "${GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX}")
    else()
      if (NOT "${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE}" MATCHES "^${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE}$")
        # ${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE} contains special regex characters
        # TODO: FIX me
        message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}invalid character(s) in branch name template \"${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE}\". set variable GIT_AUTOCOMMIT_AUTOGENBRANCH_MATCHREGEX")
      endif()
      set(BRANCH_N "[0-9]+")
      set(CURRENT_BRANCH_NAME ".*")
      set(CURRENT_BRANCH_FULL_NAME ".*")
      string(CONFIGURE ${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE} matchstring)
    endif()
    if (branchname MATCHES "^${matchstring}$")
      set(${result} 1 PARENT_SCOPE)
    else()
      set(${result} 0 PARENT_SCOPE)
    endif()
  endfunction()

  function(autocommit_author tmpt result)
    execute_git(config --get user.name)
    set(CONF_AUTHOR_NAME "${comout}")
    execute_git(config --get user.email)
    set(CONF_AUTHOR_EMAIL "${comout}")
    string(CONFIGURE "${tmpt}" res @ONLY)
    set(${result} ${res} PARENT_SCOPE)
  endfunction()



  execute_git(status -s -uall)
  if (NOT ${comres} EQUAL 0)
    message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}${comerr}")
  endif()
  set(statusout "${comout}")
  
  execute_git(log -1)
  if (NOT ${comres} EQUAL 0)
    message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}${comerr}")
  endif()
  
  if (NOT statusout STREQUAL "")
    #message(STATUS "process automatic commit")
    
    # obtain current branch name
    execute_git(symbolic-ref --short HEAD)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}could not identify current branch (you are in remote tracking branchs, tag, detached HEAD, etc...?)")
    endif()
    set(CURRENT_BRANCH_NAME "${comout}")

    execute_git(symbolic-ref HEAD)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}could not identify current branch (you are in remote tracking branchs, tag, detached HEAD, etc...?)")
    endif()
    set(CURRENT_BRANCH_FULL_NAME "${comout}")

    # determine whether or not we are already in auto-generated branch
    is_autogen_branch(${CURRENT_BRANCH_NAME} comres)
    if (${comres} EQUAL 0)
      # determine new branch name
      set(BRANCH_N ${GIT_AUTOCOMMIT_AUTOGENBRANCH_STARTNUM})
      while(1)
        string(CONFIGURE ${GIT_AUTOCOMMIT_AUTOGENBRANCH_NAMETEMPLATE} new_branchname @ONLY)
        execute_git(rev-parse -q --verify ${new_branchname})
        if (NOT ${comres} EQUAL 0)
          break()
        endif()
        math(EXPR BRANCH_N "${BRANCH_N}+1")
      endwhile()
      
      #create and checkout new branch
      message(STATUS "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}create new branch ${new_branchname}")
      execute_git(checkout -b ${new_branchname} --track ${CURRENT_BRANCH_FULL_NAME})
      if (NOT ${comres} EQUAL 0)
        message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}git checkout -b failed: ${comerr}")
      endif()
      set(CURRENT_BRANCH_NAME ${new_branchname})
    endif()
    
    #stage
    message(STATUS "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}commit to branch ${CURRENT_BRANCH_NAME}")
    execute_git(add --all .)
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}git add failed: ${comerr}")
    endif()
    
    #commit
    if (DEFINED GIT_AUTOCOMMIT_AUTHORTEMPLATE AND NOT GIT_AUTOCOMMIT_AUTHORTEMPLATE STREQUAL "")
      autocommit_author("${GIT_AUTOCOMMIT_AUTHORTEMPLATE}" nauthor)
      execute_git(commit -m ${GIT_AUTOCOMMIT_COMMIT_MESSAGE} --author=${nauthor})
    else()
      execute_git(commit -m ${GIT_AUTOCOMMIT_COMMIT_MESSAGE})
    endif()
    if (NOT ${comres} EQUAL 0)
      message(FATAL_ERROR "${GIT_AUTOCOMMIT_MESSAGE_PREFIX}git commit failed: ${comerr}")
    endif()
  endif()

elseif(DEFINED postbuild)

endif()
