InstanceSignText.helpers =
	show: (stepName)->
		if Meteor.isClient
			if Session.get('instancePrint')
				return false
			if InstanceManager.isInbox()
				myApprove = InstanceManager.getCurrentApprove()
				if myApprove
					instance = WorkflowManager.getInstance();
					myTrace = instance?.traces?.findPropertyByPK("_id", myApprove.trace)
					return myTrace?.name == stepName
		return false

	defaultDescription: ()->
#		return Template.instance().data.default_description || TAPi18n.__("instance_default_opinion")
		return Template.instance().data.default_description

	traces: ()->
		InstanceformTemplate.helpers.traces()

	trace: (stepName, only_cc_opinion, image_sign, top_keywords)->
		instance = InstanceformTemplate.helpers.instance()

		is_completed = instance?.state == "completed"

		completed_date = if is_completed then _.last(instance.traces)?.finish_date?.getTime() else 0

		traces = InstanceformTemplate.helpers.traces()

		approves = _.clone(traces[stepName])

		approve_sort = (approves, top_keywords)->

#对Approves排序， 按照提交时间排倒序，如果没有提交则显示在最上边
			approves_sorted = _.sortBy approves, (approve)->
				return -(approve.finish_date || new Date()).getTime()

			#通过关键字排序
			if top_keywords
				top_approves = new Array()

				top_keywords.split(",").forEach (key) ->
					top_approves = _.union top_approves, _.filter(approves_sorted, (approve)->
						return approve?.handler_name?.indexOf(key) > -1
					)
				# 对置顶意见按照处理事件排倒序
				top_approves = _.sortBy top_approves, (top_approve)->
					return -(top_approve.finish_date || new Date()).getTime()

				approves_sorted = _.union top_approves, approves_sorted
			return approves_sorted || []

		approves = _.filter approves, (a)->
			return a.type isnt "forward" and a.type isnt "distribute"

		if only_cc_opinion
			approves = approves?.filterProperty("type", "cc")

		approves_sorted = approve_sort(approves, top_keywords)

		approvesGroup = _.groupBy(approves, "handler");

		hasNext = (approve, approvesGroup) ->
			handlerApproves = approvesGroup[approve.handler]
			return _.indexOf(handlerApproves, approve) + 1 < handlerApproves.length

		haveDescriptionApprove = (approve, approvesGroup) ->
			handlerApproves = approvesGroup[approve.handler]

			descriptionApproves = _.filter handlerApproves, (a)->
				if a.description
					return true
				return false

			if descriptionApproves.length == 0
				return false

			return true


		approves_sorted.forEach (approve) ->
#			有输入意见 或 最新一条并且用户没有输入过意见
#			if !approve.is_finished || approve.description || (!hasNext(approve, approvesGroup) && !haveDescriptionApprove(approve, approvesGroup))
#			if !hasNext(approve, approvesGroup)
			if approve.sign_show != false
				approve._display = true

		approves_sorted = _.filter approves_sorted, (a) ->
			if is_completed
				return a._display == true && a.is_finished && a.finish_date?.getTime() <= completed_date
			else
				return a._display == true

		return approves_sorted

	include: (a, b) ->
		return InstanceformTemplate.helpers.include(a, b)

	unempty: (val)->
		return InstanceformTemplate.helpers.unempty(val)

	formatDate: (date, options)->
		if !options
			options = {"format": "YYYY-MM-DD"}

		return InstanceformTemplate.helpers.formatDate(date, options)

	isMyApprove: (approve, only_cc_opinion) ->
		if Meteor.isClient
			ins = WorkflowManager.getInstance();

			currentApprove = InstanceManager.getCurrentApprove()

			if !approve?._id
				approve = currentApprove

			if approve._id == currentApprove?._id && currentApprove?.type == 'cc' && Template.instance().data.name
				if _.indexOf(currentApprove?.opinion_fields_code, Template.instance().data.name) > -1
					return true
				else
					return false

			if !(currentApprove?.type == 'cc') && only_cc_opinion
				return false

			if currentApprove && approve._id == currentApprove._id
				return true
		return false

	myApproveDescription: (approveId)->
		if Meteor.isClient
			return TracesTemplate.helpers.myApproveDescription(approveId)

	now: ()->
		return new Date();

	isReadOnly: ()->
		if Meteor.isClient
			return ApproveManager.isReadOnly()
		return false

	isOpinionOfField: (approve)->
		if approve.type == "cc" && Template.instance().data.name
			if Template.instance().data.name == approve.sign_field_code
				return true
			else
				return false
		else
			return true;

	markDownToHtml: (markDownString)->
		if markDownString
			renderer = new Markdown.Renderer();
			renderer.link = (href, title, text) ->
				return "<a target='_blank' href='#{href}' title='#{title}'>#{text}</a>"
			return Spacebars.SafeString(Markdown(markDownString, {renderer: renderer}))

	steps: (field_formula, step, only_cc_opinion, image_sign)->
		steps = []
		if !step
			if !field_formula
				field_formula = WorkflowManager.getInstanceFormVersion()?.fields?.findPropertyByPK("code", this.name).formula
			steps = InstanceformTemplate.helpers.getOpinionFieldStepsName(field_formula, Template.instance().data.top_keywords)
		else
			steps = [{stepName: step, only_cc_opinion: only_cc_opinion, image_sign: image_sign}]
		return steps

	imageSignData: (handler) ->
		return {user: handler}

	showSignImage: (handler, image_sign) ->
		spaceUserSign = ImageSign.helpers.spaceUserSign(handler);

		if spaceUserSign?.sign && image_sign
			return true
		else
			return false

	getLastSignApprove: ()->
		ins = WorkflowManager.getInstance();

		return _.last(TracesManager.getHandlerSignShowApproves ins, Meteor.userId())


	lastMyApproveDescription: ()->
		traces = InstanceformTemplate.helpers.traces()
		currentStep = InstanceManager.getCurrentStep();
		approves = _.clone(traces[currentStep.name])

		approves = approves.filterProperty("handler", Meteor.userId())

		if approves.length > 1
			return approves[approves.length - 2]?.description

		return "";

	showApprove: (approve)->
		if approve?.is_read
			if approve.is_finished
				return ["approved", "rejected", "submitted", "readed"].includes(approve.judge)
			else
				return true;
		return false;

if Meteor.isServer
	InstanceSignText.helpers.defaultDescription = ->
		locale = Template.instance().view.template.steedosData.locale
		return Template.instance().data.default_description || TAPi18n.__("instance_default_opinion", {}, locale)