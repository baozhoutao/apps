Steedos.pushSpace = new SubsManager();

Tracker.autorun (c)->
    # Steedos.pushSpace.reset();
    Steedos.pushSpace.subscribe("raix_push_notifications");

Meteor.startup ->
    if !Steedos.isMobile()
        
        if Push.debug
            console.log("init notification observeChanges")

        query = db.raix_push_notifications.find();
        #发起获取发送通知权限请求
        $.notification.requestPermission ->

        handle = query.observeChanges(added: (id, notification) ->
            if !notification?.title && !notification?.text
                return

            options = 
                iconUrl: ''
                title: notification.title
                body: notification.text
                timeout: 6 * 1000

            if notification.payload

                options.payload = notification.payload

                options.onclick = (event) ->
                    console.log 'notification click...'

                    box = "inbox" # inbox、outbox、draft、pending、completed

                    instance_url = "/workflow/space/" + event.target.payload.space + "/" + box + "/" + event.target.payload.instance
                    
                    if Steedos.isNode() 
                        win = nw.Window.get();
                        if win
                            win.restore();
                            win.focus();
                        FlowRouter.go(instance_url);    
                    else
                        FlowRouter.go(instance_url); 
                        # window.open(instance_url);

                    # if window.cos && typeof(window.cos) == 'object'
                    #     if window.cos.win_focus && typeof(window.cos.win_focus) == 'function'
                    #         window.cos.win_focus();
                    #     FlowRouter.go(instance_url);
                    # else
                    #     window.open(instance_url);

            appName = "steedos"

            if notification.from == 'workflow'
                appName = notification.from

            options.iconUrl = Meteor.absoluteUrl() + "images/apps/" + appName + "/AppIcon48x48.png"
            
            if Push.debug
                console.log(options)

            notification = $.notification(options)
            
            # add sound
            msg = new Audio("/sound/notification.mp3")
            msg.play();

            return;
        )
    else

        if Push.debug
            console.log("add addListener")

        Push.onNotification = (data) ->
            console.log 'Push.onNotification--------------------1'
            box = 'inbox'# inbox、outbox、draft、pending、completed
            if data && data.payload
                if data.payload.space and data.payload.instance
                    instance_url = '/workflow/space/' + data.payload.space + '/' + box + '/' + data.payload.instance
                    console.log "#{instance_url}"
                    # window.open instance_url
            return

        #后台运行时，点击推送消息
        Push.addListener 'startup', (data) ->
            if Push.debug
                console.log 'Push.Startup: Got message while app was closed/in background:', data
            Push.onNotification data

        #关闭进程时，点击推送消息
        Push.addListener 'message', (data) ->
            if Push.debug
                console.log 'Push.Message: Got message while app is open:', data
            Push.onNotification data
            return