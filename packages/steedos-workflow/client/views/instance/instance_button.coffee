Template.instance_button.helpers

	enabled_save: ->
		ins = WorkflowManager.getInstance();
		if !ins
			return false
		flow = db.flows.findOne(ins.flow);
		if !flow
			return false

		if InstanceManager.isInbox()
			return true

		if !ApproveManager.isReadOnly()
			return true
		else
			return false

	enabled_delete: ->
		ins = WorkflowManager.getInstance();
		if !ins
			return false
		space = db.spaces.findOne(ins.space);
		if !space
			return false

		fl = db.flows.findOne({'_id': ins.flow});
		if !fl
			return false
		curSpaceUser = db.space_users.findOne({space: ins.space, 'user': Meteor.userId()});
		if !curSpaceUser
			return false
		organizations = db.organizations.find({_id: {$in: curSpaceUser.organizations}}).fetch();
		if !organizations
			return false

		if Session.get("box") == "draft" || (Session.get("box") == "monitor" && (space.admins.contains(Meteor.userId()) || WorkflowManager.canAdmin(fl, curSpaceUser, organizations)))
			return true
		else
			return false

	enabled_print: ->
		# 如果是手机版APP，则不显示打印按钮
		if Meteor.isCordova
			return false
		return true

	enabled_terminate: ->
		# 隐藏取消申请按钮
		if Meteor.settings.public?.workflow?.hideTerminateButton
			return false

		ins = WorkflowManager.getInstance();
		if !ins
			return false
		if (Session.get("box") == "pending" || Session.get("box") == "inbox") && ins.state == "pending" && ins.applicant == Meteor.userId()
			return true
		else
			return false

	enabled_reassign: ->
		ins = WorkflowManager.getInstance();
		if !ins
			return false
		space = db.spaces.findOne(ins.space);
		if !space
			return false
		fl = db.flows.findOne({'_id': ins.flow});
		if !fl
			return false
		curSpaceUser = db.space_users.findOne({space: ins.space, 'user': Meteor.userId()});
		if !curSpaceUser
			return false
		organizations = db.organizations.find({_id: {$in: curSpaceUser.organizations}}).fetch();
		if !organizations
			return false

		if Session.get("box") == "monitor" && ins.state == "pending" && (space.admins.contains(Meteor.userId()) || WorkflowManager.canAdmin(fl, curSpaceUser, organizations))
			return true
		else
			return false

	enabled_relocate: ->
		ins = WorkflowManager.getInstance();
		if !ins
			return false
		space = db.spaces.findOne(ins.space);
		if !space
			return false
		fl = db.flows.findOne({'_id': ins.flow});
		if !fl
			return false
		curSpaceUser = db.space_users.findOne({space: ins.space, 'user': Meteor.userId()});
		if !curSpaceUser
			return false
		organizations = db.organizations.find({_id: {$in: curSpaceUser.organizations}}).fetch();
		if !organizations
			return false

		if Session.get("box") == "monitor" && ins.state != "draft" && (space.admins.contains(Meteor.userId()) || WorkflowManager.canAdmin(fl, curSpaceUser, organizations))
			return true
		else
			return false

	enabled_cc: ->
		ins = WorkflowManager.getInstance()
		if !ins
			return false
		# 文件结束后，不可以再传阅，也不用再催办。
		if InstanceManager.isInbox() && ins.state is "pending" 
			if InstanceManager.isCC(ins)
				return true
			else
				cs = InstanceManager.getCurrentStep()
				if cs && (cs.disableCC is true)
					return false
				return true
		else if Session.get("box") is 'outbox' and ins.state is "pending"
			step_id = InstanceManager.getLastTraceStepId(ins.traces)
			if step_id
				step = WorkflowManager.getInstanceStep(step_id)
				if step and (step.disableCC is true)
					return false
				return true
			else
				return false
		else
			return false

	#是否需要退回按钮
	enabled_return: ->
		ins = WorkflowManager.getInstance()
		if !ins
			return false
		flow = db.flows.findOne(ins.flow)
		if !flow
			return false

		if !InstanceManager.isInbox()
			return false

		if InstanceManager.isCC(ins)
			return false

		if ins.traces.length < 2 # 通过转发生成的文件也在待审核箱中但是状态为draft并且ins.traces.length=1
			return false

		pre_trace = ins.traces[ins.traces.length - 2]

		is_relocated = false
		_.each pre_trace.approves, (ap)->
			if ap.judge is 'relocated'
				is_relocated = true
		if is_relocated
			return false

		pre_step = WorkflowManager.getInstanceStep(pre_trace.step)
		if pre_step && pre_step.step_type is "counterSign"
			return false

		cs = InstanceManager.getCurrentStep()
		if _.isEmpty(cs)
			return false
		if cs.step_type is "submit"
			return true

		return false


	enabled_forward: ->
		if Meteor.settings.public?.workflow?.disableInstanceForward
			return false

		ins = WorkflowManager.getInstance()
		if !ins
			return false

		# 传阅的申请单不允许转发
		if (InstanceManager.isCC(ins))
			return false

		# 待审核箱不显示转发
		if InstanceManager.isInbox()
			return false

		if ins.state != "draft"
			return true
		else
			return false

	enabled_distribute: ->
		ins = WorkflowManager.getInstance()
		if !ins
			return false

		# 传阅的申请单不允许分发
		if (InstanceManager.isCC(ins))
			return false

		# 设置了允许分发才显示分发按钮
		if InstanceManager.isInbox()
			cs = InstanceManager.getCurrentStep()
			if cs && (cs.allowDistribute is true)
				return true
		
		return false

	enabled_retrieve: ->
		ins = WorkflowManager.getInstance()
		if !ins
			return false

		if (Session.get('box') is 'outbox' or Session.get('box') is 'pending') and ins.state isnt 'draft'
			return true
			# last_trace = _.last(ins.traces)
			# previous_trace_id = last_trace.previous_trace_ids[0]
			# previous_trace = _.find(ins.traces, (t)->
			# 	return t._id is previous_trace_id
			# )
			# # 校验当前步骤是否已读
			# is_read = false
			# _.each last_trace.approves, (ap)->
			# 	if ap.is_read is true
			# 		is_read = true
			# # 取回步骤的前一个步骤处理人唯一（即排除掉传阅和转发的approve后，剩余的approve只有一个）并且是当前用户
			# previous_trace_approves = _.filter previous_trace.approves, (a)->
			# 	return a.type isnt 'cc' and a.type isnt 'distribute' and ['approved','submitted','rejected'].includes(a.judge)

			# if previous_trace_approves.length is 1 and previous_trace_approves[0].user is Meteor.userId() and not is_read
			# 	return true
		return false

	enabled_traces: ->
		if Session.get("box") == "draft"
			return false
		else
			return true

	enabled_copy: ->
		if Session.get("box") == "draft"
			return false
		else
			return true

	enabled_related: ->
		if Session.get("box") == "draft"
			current_step = InstanceManager.getCurrentStep()
			if current_step
				if (current_step.can_edit_main_attach || current_step.can_edit_normal_attach == true || current_step.can_edit_normal_attach == undefined)
					return true
		else
			return false

	instance_readonly_view_url: ->
		href = Meteor.absoluteUrl("workflow/space/"+Session.get("spaceId")+"/view/readonly/" + Session.get("instanceId"))
		ins = WorkflowManager.getInstance()
		if !ins
			return ""
		instanceName = ins.name
		return "[#{instanceName}](#{href})"

	enabled_suggest: ->
#		isShow = !ApproveManager.isReadOnly() || InstanceManager.isInbox();
#		if isShow
#			isShow = WorkflowManager.getInstance().state != "draft"
#		return isShow
		return false

	enabled_remind: ->
		ins = WorkflowManager.getInstance();
		if !ins
			return false

		# 文件结束后，不可以再传阅，也不用再催办。
		if ins.state != "pending"
			return false

#		if !Steedos.isPaidSpace()
#			return false

		values = ins.values || new Object

		try
			if values.priority and values.deadline
				check values.priority, Match.OneOf('普通', '办文', '紧急', '特急')
				# 由于values中的date字段的值为String，故作如下校验
				if new Date(values.deadline).toString() is "Invalid Date"
					return false
		catch e
			return false

		space = db.spaces.findOne(ins.space);
		if !space
			return false
		fl = db.flows.findOne({'_id': ins.flow});
		if !fl
			return false
		curSpaceUser = db.space_users.findOne({space: ins.space, 'user': Meteor.userId()});
		if !curSpaceUser
			return false
		organizations = db.organizations.find({_id: {$in: curSpaceUser.organizations}}).fetch();
		if !organizations
			return false

		this.remind_action_types = []

		if Session.get("box") == "monitor" && ins.state == "pending" && (space.admins.contains(Meteor.userId()) || WorkflowManager.canAdmin(fl, curSpaceUser, organizations))
			this.remind_action_types.push 'admin'

		if Session.get("box") == "pending" && ins.state == "pending" && ins.applicant is Meteor.userId()
			this.remind_action_types.push 'applicant'


		# 传阅出去的申请单如果有还未处理的也可催办
		cc_approves_not_finished = new Array
		_.each ins.traces, (t)->
			_.each t.approves, (ap)->
				if ap.type is 'cc' and ap.from_user is Meteor.userId() and ap.is_finished isnt true
					cc_approves_not_finished.push(ap._id)

		if (Session.get("box") == "inbox" or Session.get("box") == "inbox") and not _.isEmpty(cc_approves_not_finished)
			this.remind_action_types.push 'cc'

		if this.remind_action_types.includes('admin') || this.remind_action_types.includes('applicant') || this.remind_action_types.includes('cc')
			return true

		return false

	enabled_submit: ()->
		ins = WorkflowManager.getInstance();
		if !ins
			return false

		if InstanceManager.isInbox()
			return true

		return false

	isMobile: ()->
		return Steedos.isMobile()

Template.instance_button.onRendered ->
	$('[data-toggle="tooltip"]').tooltip();
	copyUrlClipboard = new Clipboard('.btn-instance-readonly-view-url-copy');

	Template.instance_button.copyUrlClipboard = copyUrlClipboard

	copyUrlClipboard.on 'success', (e) ->
		toastr.success(t("instance_readonly_view_url_copy_success"))
		e.clearSelection()

Template.instance_button.onDestroyed ->
	Template.instance_button.copyUrlClipboard.destroy();

Template.instance_button.events

	'click .btn-instance-to-print': (event)->
		if window.navigator.userAgent.toLocaleLowerCase().indexOf("chrome") < 0
				toastr.warning(TAPi18n.__("instance_chrome_print_warning"))
		else
				uobj = {}
				uobj["box"] = Session.get("box")
				uobj["X-User-Id"] = Meteor.userId()
				uobj["X-Auth-Token"] = Accounts._storedLoginToken()
				Steedos.openWindow(Steedos.absoluteUrl("workflow/space/" + Session.get("spaceId") + "/print/" + Session.get("instanceId") + "?" + $.param(uobj)), "",'width=900,height=750,scrollbars=yes,EnableViewPortScale=yes,toolbarposition=top,transitionstyle=fliphorizontal,menubar=yes,closebuttoncaption=  x  ')

	'click .btn-instance-update': (event)->

		element = $(".btn-instance-update")

		if !InstanceEvent.run(element, "instance-before-save")
			return ;

		InstanceManager.saveIns();
		Session.set("instance_change", false);

	'click .btn-instance-remove': (event)->
		swal {
			title: t("Are you sure?"),
			type: "warning",
			showCancelButton: true,
			cancelButtonText: t('Cancel'),
			confirmButtonColor: "#DD6B55",
			confirmButtonText: t('OK'),
			closeOnConfirm: true
		}, () ->
			Session.set("instance_change", false);
			InstanceManager.deleteIns()

	'click .btn-instance-force-end': (event)->
		swal {
			title: t("instance_cancel_title"),
			text: t("instance_cancel_reason"),
			type: "input",
			confirmButtonText: t('OK'),
			cancelButtonText: t('Cancel'),
			showCancelButton: true,
			closeOnConfirm: false
		}, (reason) ->
			# 用户选择取消
			if (reason == false)
				return false;

			if (reason == "")
				swal.showInputError(t("instance_cancel_error_reason_required"));
				return false;

			InstanceManager.terminateIns(reason);
			sweetAlert.close();

	'click .btn-instance-reassign': (event, template) ->
		Modal.show('reassign_modal')

	'click .btn-instance-relocate': (event, template) ->
		Modal.show('relocate_modal')


	'click .btn-instance-cc': (event, template) ->
		Modal.show('instance_cc_modal');

	'click .btn-instance-return': (event, template) ->
		swal {
			title: TAPi18n.__("instance_return_confirm"),
			type: "warning",
			showCancelButton: true,
			cancelButtonText: t('Cancel'),
			confirmButtonColor: "#DD6B55",
			confirmButtonText: t('OK'),
			closeOnConfirm: true
		}, () ->
			$("body").addClass("loading")
			Meteor.call "instance_return", InstanceManager.getMyApprove(), (err, result)->
				$("body").removeClass("loading")
				if err
					toastr.error TAPi18n.__(err.reason)
				if result == true
					FlowRouter.go("/workflow/space/" + Session.get("spaceId") + "/" + Session.get("box"));
					toastr.success(TAPi18n.__('instance_return_success'));
				return

	'click .btn-instance-forward': (event, template) ->
		if !Steedos.isPaidSpace()
			Steedos.spaceUpgradedModal()
			return;

		Modal.show("forward_select_flow_modal", {action_type:"forward"})

	'click .btn-instance-distribute': (event, template) ->
		if !Steedos.isPaidSpace()
			Steedos.spaceUpgradedModal()
			return;

		Modal.show("forward_select_flow_modal", {action_type:"distribute"})

	'click .btn-instance-retrieve': (event, template) ->
		ins = WorkflowManager.getInstance()
		traces = ins.traces
		can_retrieve = false
		current_user = Meteor.userId()

		if (Session.get('box') is 'outbox' or Session.get('box') is 'pending') and ins.state isnt 'draft'
			last_trace = _.last(traces)
			previous_trace_id = last_trace.previous_trace_ids[0]
			previous_trace = _.find(traces, (t)->
				return t._id is previous_trace_id
			)
			# 校验当前步骤是否已读
			is_read = false
			_.each last_trace.approves, (ap)->
				if ap.is_read is true
					is_read = true
			# 取回步骤的前一个步骤处理人唯一（即排除掉传阅和转发的approve后，剩余的approve只有一个）并且是当前用户
			previous_trace_approves = _.filter previous_trace.approves, (a)->
				return a.type isnt 'cc' and a.type isnt 'distribute' and ['approved','submitted','rejected'].includes(a.judge)

			if previous_trace_approves.length is 1 and (previous_trace_approves[0].user is current_user or previous_trace_approves[0].handler is current_user) and not is_read
				can_retrieve = true

		i = traces.length
		while i > 0
			_.each traces[i-1].approves, (a)->
				if a.type is 'cc' and a.is_finished is true and a.user is current_user
					can_retrieve = true
			if can_retrieve is true
				break
			i--

		if can_retrieve
			swal {
				title: t("instance_retrieve"),
				inputPlaceholder: t("instance_retrieve_reason"),
				type: "input",
				confirmButtonText: t('OK'),
				cancelButtonText: t('Cancel'),
				showCancelButton: true,
				closeOnConfirm: false
			}, (reason) ->
				# 用户选择取消
				if (reason == false)
					return false;

	#			if (reason == "")
	#				swal.showInputError(t("instance_retrieve_reason"));
	#				return false;

				InstanceManager.retrieveIns(reason);
				sweetAlert.close();
		else
			swal({
				title: t("instance_retrieve_rules_title"),
				text: "<div style='overflow-x:auto;'>#{t('instance_retrieve_rules_content')}<div>",
				html: true,
				confirmButtonText: t('OK')
			})

	'click .btn-trace-list': (event, template) ->
		ins = WorkflowManager.getInstance();
		if !TracesTemplate.helpers.showTracesView(ins.form, ins.form_version)
			$("body").addClass("loading")
#			延迟一毫秒弹出Modal，否则导致loading显示不出来
			Meteor.setTimeout ()->
				Modal.show("traces_table_modal")
			, 1

		else
			$(".instance").scrollTop($(".instance .instance-form").height())

	'click .li-instance-readonly-view-url-copy': (event, template)->
		$(".btn-instance-readonly-view-url-copy").click();

	'click .btn-instance-related-instances': (event, template)->
		if !Steedos.isPaidSpace()
			Steedos.spaceUpgradedModal()
			return;
		Modal.show("related_instances_modal")

	'click .btn-workflow-chart': (event, template)->
		if Steedos.isIE()
			toastr.warning t("instance_workflow_chart_ie_warning")
			return
		ins = WorkflowManager.getInstance()
		flow = db.flows.findOne(ins.flow)
		Steedos.openWindow(Steedos.absoluteUrl("/packages/steedos_workflow-chart/assets/index.html?instance_id=#{ins._id}&flow_name=#{encodeURIComponent(encodeURIComponent(flow.name))}"),'workflow_chart')

	'click .btn-suggestion-toggle': (event, template)->
		$(".instance-wrapper .instance-view").addClass("suggestion-active")
		InstanceManager.fixInstancePosition()

	'click .btn-instance-remind': (event, template) ->
		if !Steedos.isPaidSpace()
			Steedos.spaceUpgradedModal()
			return;

		param = {action_types: template.data.remind_action_types || []}
		Modal.show 'remind_modal', param

	'click .btn-instance-submit': (event, template) ->
		instance = WorkflowManager.getInstance()
		if not InstanceManager.isCC(instance)
			nextStepOptions = InstanceManager.getNextStepOptions()
			if nextStepOptions.length > 1
				$(".instance-wrapper .instance-view").addClass("suggestion-active")
				toastr.error TAPi18n.__("instance_multi_next_step_tips")
				return

			nextStep = nextStepOptions[0]
			if nextStep.type isnt 'end'
				if ApproveManager.getNextStepUsersSelectValue().length == 0
					$(".instance-wrapper .instance-view").addClass("suggestion-active")
					toastr.error TAPi18n.__("instance_next_step_user")
					return

		$('#instance_submit').trigger('click')