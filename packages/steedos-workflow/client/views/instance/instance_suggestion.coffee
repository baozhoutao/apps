Template.instance_suggestion.helpers

	equals: (a, b) ->
		return (a == b)

	includes: (a, b) ->
		return b.split(',').includes(a);

	suggestion_box_style: ->
		judge = Session.get("judge")
		if judge
			if (judge == "approved")
				return "box-success"
			else if (judge == "rejected")
				return "box-danger"

	show_toggle_button: ->
		isShow = !ApproveManager.isReadOnly() || InstanceManager.isInbox();
		if isShow
			isShow = WorkflowManager.getInstance().state != "draft"
		return isShow

	show_suggestion: ->
		return !ApproveManager.isReadOnly() || InstanceManager.isInbox();

	currentStep: ->
		return InstanceManager.getCurrentStep();

	currentApprove: ->
		approve = {}

		if Session.get("box") != "inbox" && Session.get("box") != "draft"
			return approve

		instance = WorkflowManager.getInstance();

#		if InstanceManager.isCC(instance)
#			approve = InstanceManager.getCCApprove(Meteor.userId(), false);
		approve = InstanceManager.getCurrentApprove();

#		if approve
#			description = approve.description || InstanceSignText.helpers.getLastSignApprove()?.description || ""
#			Session.set("instance_my_approve_description", description)
		return approve
	next_step_multiple: ->
		Session.get("next_step_multiple")

	next_user_multiple: ->
		Session.get("next_user_multiple")

	next_step_options: ->
		ins_applicant = Session.get("ins_applicant");
		instance_form_values = Session.get("instance_form_values")
		if instance_form_values?.instanceId == Session.get("instanceId")
			return InstanceManager.getNextStepOptions();

	#next_user_options: ->
	#    return InstanceManager.getNextUserOptions();

	next_user_context: ->
		instance_form_values = Session.get("instance_form_values")
		if instance_form_values?.instanceId != Session.get("instanceId")
			return {};

		ins_applicant = Session.get("ins_applicant");

		next_step_id = Session.get("next_step_id");

		$("#nextStepUsers_div").show();

		if next_step_id
			nextStep = WorkflowManager.getInstanceStep(next_step_id)
			if nextStep && nextStep.step_type == 'end'
				$("#nextStepUsers_div").hide();


		form_values = instance_form_values.values
		users = InstanceManager.getNextUserOptions();
		data = {
			dataset: {is_within_user_organizations: Meteor.settings?.public?.workflow?.user_selection_within_user_organizations || false},
			name: 'nextStepUsers',
			atts: {
				name: 'nextStepUsers',
				id: 'nextStepUsers',
				class: 'selectUser nextStepUsers form-control',
				style: 'padding:6px 12px;',
				placeholder: t("instance_next_step_users_placeholder")
			}
		};

		unless nextStep
			data.atts.disabled = true

		next_user = $("input[name='nextStepUsers']");


		selectedUser = [];


		users.forEach (user) ->
			if user.selected
				selectedUser.push(user);

		if users.length == 1 && selectedUser.length < 1
			selectedUser = [users[0]];


		if next_user && next_user.length > 0

			#先清空下一步处理人
			next_user[0].value = ''
			next_user[0].dataset.values = ''


			if !Session.get("next_step_users_showOrg")
				next_user[0].dataset.userOptions = users.getProperty("id")
				next_user[0].dataset.showOrg = false;
			else
				delete next_user[0].dataset.userOptions
				delete next_user[0].dataset.showOrg

			next_user[0].dataset.multiple = Session.get("next_user_multiple");

			next_userIds = []
			next_userIdObjs = []
			if next_user[0].value != ""
				next_userIds = next_user[0].dataset.values.split(",");
				next_userIdObjs = users.filterProperty("id", next_userIds)

			if next_userIds.length > 0 && next_userIdObjs.length > 0 && next_userIds.length = next_userIdObjs.length
				next_user[0].value = next_userIdObjs.getProperty("name").toString();
				next_user[0].dataset.values = next_userIdObjs.getProperty("id").toString();
				data.value = next_user[0].value;
				data.dataset['values'] = next_user[0].dataset.values;
			else
				next_user[0].value = selectedUser.getProperty("name").toString();
				next_user[0].dataset.values = selectedUser.getProperty("id").toString()
				data.value = next_user[0].value
				data.dataset['values'] = selectedUser.getProperty("id").toString()
		else
			if !Session.get("next_step_users_showOrg")
				data.dataset['userOptions'] = users.getProperty("id")
				data.dataset['showOrg'] = false;

			data.dataset['multiple'] = Session.get("next_user_multiple");

			data.value = selectedUser
			data.dataset['values'] = selectedUser.getProperty("id").toString()
		return data;

	judge: ->
		currentApprove = InstanceManager.getCurrentApprove();
		if !Session.get("judge")
			Session.set("judge", currentApprove?.judge);

		if !Session.get("judge")
			currentStep = InstanceManager.getCurrentStep();
			# 默认核准
			if (currentStep.step_type == "sign" || currentStep.step_type == "counterSign")
				Session.set("judge", "approved");

		currentApprove?.judge = Session.get("judge");

		return Session.get("judge")

	isCC: ->
		instance = WorkflowManager.getInstance();
		return InstanceManager.isCC(instance);

	enabled_submit: ->
		ins = WorkflowManager.getInstance()
		if !ins
			return false
		flow = db.flows.findOne(ins.flow)
		if !flow
			return false
		if InstanceManager.isInbox()
			return true
		if !ApproveManager.isReadOnly()
			return true
		else
			return false

	isReady: ->
		return Session.get("instance_suggestion_ready");

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
		pre_step = WorkflowManager.getInstanceStep(pre_trace.step)
		if pre_step && pre_step.step_type is "counterSign"
			return false

		cs = InstanceManager.getCurrentStep()
		if _.isEmpty(cs)
			return false
		if cs.step_type is "submit"
			return true

		return false

	hideCounterSignJudgeOptions: ->
		return Meteor.settings.public?.workflow?.hideCounterSignJudgeOptions

	cc_opinion_field_code: ->
		cc_approve = InstanceManager.getCurrentApprove();

		if cc_approve?.sign_field_code
			form_version = WorkflowManager.getInstanceFormVersion();
			fields = form_version?.fields

			return fields?.findPropertyByPK("code", cc_approve.sign_field_code)?.name || cc_approve.sign_field_code

		return t("instance_cc_title")

	gt: (a, b)->
		return a > b;

	opinionFields: ->
		currentApprove = InstanceManager.getCurrentApprove()
		opinionFields = _.filter(form_version.fields, (field) ->
			if currentApprove.type == 'cc'
				return InstanceformTemplate.helpers.isOpinionField(field) and _.indexOf(currentApprove.opinion_fields_code, field.code) > -1
			InstanceformTemplate.helpers.isOpinionField(field) and InstanceformTemplate.helpers.getOpinionFieldStepsName(field.formula).filterProperty('stepName', currentStep.name).length > 0
		)

		opinionFields.forEach (field) ->
			field.name = field.name || field.code

			field._checked = currentApprove?.sign_field_code == field.code

		return opinionFields

	ccDescription: ->
		return InstanceManager.getCurrentApprove().cc_description

	ccFromUserName: ->
		return InstanceManager.getCurrentApprove().from_user_name


Template.instance_suggestion.events

	'change .suggestion': (event) ->
		if ApproveManager.isReadOnly()
			return;
		judge = $("[name='judge']").filter(':checked').val();
		Session.set("next_step_id", null);
		Session.set("judge", judge);

	# 'change .nextSteps': (event) ->
	# 	if event.target.name == 'nextSteps'
	# 		if $("#nextSteps").find("option:selected").attr("steptype") == 'counterSign'
	# 			Session.set("next_user_multiple", true)
	# 		else
	# 			Session.set("next_user_multiple", false)
	# 		Session.set("next_step_id", $("#nextSteps").val())

	'change [name=instance_suggestion_next_step]': (event) ->
		checkedNextStepRadio = $("[name=instance_suggestion_next_step]:checked")
		if checkedNextStepRadio.attr("steptype") == 'counterSign'
			Session.set("next_user_multiple", true)
		else
			Session.set("next_user_multiple", false)
		Session.set("next_step_id", checkedNextStepRadio.val())

	'click #instance_flow_opinions': (event, template)->
		Session.set('flow_comment', $("#suggestion").val())
		Modal.show 'opinion_modal', {parentNode: $("#suggestion")}

	'input #suggestion': (event, template) ->
		InstanceManager.checkSuggestion();
		Session.set("instance_my_approve_description", $("#suggestion").val())

	'click #instance_submit': (event)->
		if WorkflowManager.isArrearageSpace()
			ins = WorkflowManager.getInstance();
			if ins.state == "draft"
				toastr.error(t("spaces_isarrearageSpace"));
				return
		if !ApproveManager.isReadOnly()
			InstanceManager.checkFormValue();
		if($(".has-error").length == 0)
			c = InstanceManager.getCurrentStep();
			if c && c.cc_alert == true 
				swal {
					title: TAPi18n.__('instance_cc_alert'),
					type: "warning",
					showCancelButton: true,
					cancelButtonText: t('form_field_checkbox_no'),
					confirmButtonColor: "#DD6B55",
					confirmButtonText: t('form_field_checkbox_yes'),
					closeOnConfirm: true
				}, (isConfirm) ->
					if (!isConfirm)
						Session.set("instance_change", false);
						InstanceManager.submitIns();
			else 
				Session.set("instance_change", false);
				InstanceManager.submitIns();
		InstanceManager.fixInstancePosition()

	'change input[name=judge]': (event)->
		if $('input[name=judge]:checked').val() == "approved"
			InstanceManager.checkSuggestion()
		InstanceManager.fixInstancePosition()

	'click .btn-suggestion-toggle,.instance-suggestion .btn-remove': (event, template)->
		$(".instance-wrapper .instance-view").toggleClass("suggestion-active")
		InstanceManager.fixInstancePosition()

	'change #opinion_fields_code': (event, template)->
		console.log("change opinion_fields_code")

		myApprove = InstanceManager.getCurrentApprove()

		Meteor.call 'update_approve_sign', myApprove.instance, myApprove.trace, myApprove._id, event.target.value, $("#suggestion").val(), "update", InstanceSignText.helpers.getLastSignApprove()


Template.instance_suggestion.onCreated ->
	console.log("instance_suggestion onCreated...");

Template.instance_suggestion.onRendered ->
	Session.set("instance_suggestion_ready", true)
	currentStep = InstanceManager.getCurrentStep();
	# 当前步骤为会签时，不显示下一步步骤、处理人
	if currentStep && currentStep.step_type == 'counterSign'
		$(".instance-suggestion #instance_next").hide();


	next_step_id = Session.get("next_step_id");

	$("#nextStepUsers_div").show();

	if next_step_id
		nextStep = WorkflowManager.getInstanceStep(next_step_id)
		if nextStep && nextStep.step_type == 'end'
			$("#nextStepUsers_div").hide();

Template.instance_suggestion.onDestroyed ->
	Session.set("instance_suggestion_ready", false)
	Session.set("instance_my_approve_description", null)