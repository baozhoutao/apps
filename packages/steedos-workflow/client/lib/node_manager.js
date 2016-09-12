NodeManager = {};
//定义全局变量;
NodeManager.fileSHA1; 

var url, net, path, http, fs, crypto, exec
if (window.require){
    url = window.require('url');
    net = window.require('net');
    path = window.require('path');
    http = window.require('http');
    fs = window.require('fs');
    crypto = window.require('crypto');
    exec = window.require('child_process').exec;
}

function setCos_Signal(str){
    if(window.cos){
        cos.office_signal = str;
    }
}

// 客户端上传附件
NodeManager.uploadAttach = function(fileDataInfo, fileKeyValue, req) {
    var boundaryKey = Math.random().toString(16);
    var enddata = '\r\n----' + boundaryKey + '--';
    var fileinfo = fileDataInfo;
    var filevalue = fileKeyValue;
    var dataLength = 0;
    var dataArr = new Array();
    for (var i = 0; i < fileDataInfo.length; i++) {
        var dataInfo = "\r\n----" + boundaryKey + "\r\n" + "Content-Disposition: form-data; name=\"" + fileDataInfo[i].urlValue + "\"\r\n\r\n" + fileDataInfo[i].urlValue;
        var dataBinary = new Buffer(dataInfo, "utf-8");
        dataLength += dataBinary.length;
        dataArr.push({
            dataInfo: dataInfo
        });
    }
    
    var files = new Array();
    for (var i = 0; i < fileKeyValue.length; i++) {
        var content = "\r\n----" + boundaryKey + "\r\n" + "Content-Type: " + fileKeyValue[i].urlKey + "\r\n" + "Content-Disposition: form-data; name=\"" + fileKeyValue[i].urlname + "\"; filename=\"" + path.basename(fileKeyValue[i].urlValue) + "\"\r\n" + "Content-Transfer-Encoding: binary\r\n\r\n";
        var contentBinary = new Buffer(content, 'utf-8'); //当编码为ascii时，中文会乱码。
        files.push({
            contentBinary: contentBinary,
            filePath: fileKeyValue[i].urlValue
        });
    }
    var contentLength = 0;
    for (var i = 0; i < files.length; i++) {
        var filePath = files[i].filePath;
        if (fs.existsSync(filePath)) {
            var stat = fs.statSync(filePath);
            contentLength += stat.size;
        } else {
            contentLength += new Buffer("\r\n", 'utf-8').length;
        }
        contentLength += files[i].contentBinary.length;
    }

    req.setHeader('Content-Type', 'multipart/form-data; boundary=--' + boundaryKey);
    req.setHeader('Content-Length', dataLength + contentLength + Buffer.byteLength(enddata));

    // 将参数发出
    for (var i = 0; i < dataArr.length; i++) {
        req.write(dataArr[i].dataInfo)
        //req.write('\r\n')
    }

    var fileindex = 0;
    var doOneFile = function() {
        req.write(files[fileindex].contentBinary);
        var currentFilePath = files[fileindex].filePath;
        if (fs.existsSync(currentFilePath)) {
            var fileStream = fs.createReadStream(currentFilePath, {bufferSize: 4 * 1024});
            fileStream.pipe(req, {end: false});
            fileStream.on('end', function() {
                fileindex++;
                if (fileindex == files.length) {
                    req.end(enddata);
                } else {
                    doOneFile();
                }
            });
        } else {
            req.write("\r\n");
            fileindex++;
            if (fileindex == files.length) {
                req.end(enddata);
            } else {
                doOneFile();
            }
        }
    };
    if (fileindex == files.length) {
        req.end(enddata);
    } else {
        doOneFile();
    }
}

NodeManager.setUploadRequests = function(filePath, filename){
    
    $(document.body).addClass("loading");
    $('.loading-text').text(TAPi18n.__("workflow_attachment_uploading") + filename + "...");
    var fileDataInfo = [
        {urlKey: "name", urlValue: filename}
    ]

    var files = [
        {urlKey: cfs.getContentType(filename), urlname: filename, urlValue: filePath}
    ]
    // 配置附件上传接口
    var options = {
        host: url.parse(Meteor.absoluteUrl()).hostname,
        port: url.parse(Meteor.absoluteUrl()).port,
        method: "POST",
        path: "/s3/"
    }
    var req = http.request(options, function(res) {
        var fileObj = {};
        res.on('data', function(chunk) {
            var chunkStr = JSON.parse(chunk.toString());          
            fileObj._id = chunkStr.version_id;
            fileObj.name = filename;
            fileObj.type = cfs.getContentType(filename);
            fileObj.size = chunkStr.size;
        });
        // res.setEncoding("utf8");
        res.on('end', function() {
            $(document.body).removeClass('loading');
            $('.loading-text').text("");
            
            // 成功上传后删除本地文件
            fs.unlinkSync(filePath);
            
            // 表单添加附件
            InstanceManager.addAttach(fileObj, false);
        });
    })

    req.on('error', function(e) {
        $(document.body).removeClass('loading');
        $('.loading-text').text("");
        console.log('problem with request:' + e.message);
        toastr.error(e.message);
    });

    NodeManager.uploadAttach(fileDataInfo, files, req);
    Modal.hide("attachments_upload_modal");
}

// 获取文件hash值
NodeManager.getFileSHA1 = function(filePath, filename, callback){
    var fd = fs.createReadStream(filePath);
    var hash = crypto.createHash('sha1');
    hash.setEncoding('hex');
    fd.pipe(hash);
    fd.on('end', function(){
        hash.end();
        var SHA1 = hash.read();
        console.log('hash.read() ' + SHA1); // the desired sha1sum
        callback(SHA1);
    });
}

// 使用edit.vbs打开本地office
NodeManager.vbsEditFile = function(download_dir, filename){
    var filePath = download_dir + filename;

    var homePath = process.cwd() ;
    var cmd = '\"' + homePath + '\"' + '\\vbs\\edit.vbs ' + '\"' + filePath + '\" ' + Meteor.users.findOne().name;
    console.log(cmd);

    Modal.show("attachments_upload_modal",{filePath: filePath});
    
    // 专业版文件大小不能超过100M
    var maximumFileSize = 100 * 1024 * 1024;
    // 免费版大小不能超过1M
    var freeMaximumFileSize = 1024 * 1024;

    var limitSize, warnStr;

    var is_paid = WorkflowManager.isPaidSpace(Session.get('spaceId'));

    if (is_paid) {
      limitSize = maximumFileSize;
      warnStr = t("workflow_attachment_paid_size_limit");
    }
    else {
      limitSize = freeMaximumFileSize;
      warnStr = t("workflow_attachment_free_size_limit");
    }
    // 执行vbs编辑word
    var child = exec(cmd);
    //正在编辑
    setCos_Signal("editing");
    
    child.on('error',function(error){
        console.error(error);
    });
    child.on('close',function(){
        // 完成编辑
        Modal.hide("attachments_upload_modal");
        
        // 修改后附件大小
        var states =  fs.statSync(filePath);
        console.log('states.size: ' + states.size);
        
        setCos_Signal("finished");
        NodeManager.getFileSHA1(filePath,filename,function(sha1){
            if(NodeManager.fileSHA1 != sha1){
                var setting = {
                        title: t("node_office_warning"),
                        text: filePath, 
                        type: "warning",  
                        showCancelButton: true,
                        confirmButtonText: t("node_office_confirm"),   
                        cancelButtonText: t("node_office_cancel")
                    }
                
                if (states.size > limitSize) {
                    setting.closeOnConfirm = false;
                }   
                // 提示确认信息
                swal(setting, function(isConfirm){
                    if (isConfirm) { 
                        if (states.size > limitSize) {
                            swal({
                                title: warnStr,
                                type: "warning",
                                confirmButtonText: t("node_office_confirm"),
                                closeOnConfirm: true
                            }, function(){
                                NodeManager.vbsEditFile(download_dir, filename);
                            });
                        }else{
                            NodeManager.setUploadRequests(filePath, filename);
                        }
                    }
                })
            }
        })
    })         
}

// 下载文件
NodeManager.downloadFile = function(file_url, download_dir, filename){
    $(document.body).addClass("loading");
    $('.loading-text').text(TAPi18n.__("workflow_attachment_downloading") + filename + "...");
    var filePath = path.join(download_dir,filename) ;
    var file = fs.createWriteStream(filePath);
    var dfile = http.get(encodeURI(file_url), function(res) {
        res.on('data', function(data) {
                file.write(data);
        }).on('end', function(){
            file.end();
            $(document.body).removeClass('loading');
            $('.loading-text').text("");
            // 获取附件hash值
            NodeManager.getFileSHA1(filePath, filename, function(sha1){
                NodeManager.fileSHA1 = sha1;
            });
            // 调用edit.vbs对word文档进行在线编辑
            NodeManager.vbsEditFile(download_dir, filename);
        })
    });
    dfile.on('error',function(e){
        $(document.body).removeClass('loading');
        $('.loading-text').text("");
        console.log(e.message);
    })
}

// 编辑文件
NodeManager.editFile = function(file_url, filename){
    var download_dir = "";
    //获取系统Documents路径
    var docPath = process.env.USERPROFILE + "\\Documents\\";
    fs.exists(docPath,function(exists){
        if (exists == true){
            download_dir = docPath + t('Workflow') + "\\";
        }else{
            download_dir = process.env.USERPROFILE + "\\My Documents\\" + t('Workflow') + "\\";
        }
        // 判断附件保存路径是否存在
        fs.exists(download_dir,function(exists){
            if (exists == true){
                var fPath = download_dir + filename;
                console.log(fPath);
                fs.exists(fPath,function(exists){
                    if (exists == true){
                        swal({
                                title: t("node_office_exists_message"),
                                text: fPath,
                                type: "warning", 
                                showCancelButton: true,
                                confirmButtonText: t("node_office_confirm"),   
                                cancelButtonText: t("node_office_cancel")
                            }, function(isConfirm){
                                if (isConfirm){
                                    // 下载附件到本地
                                    NodeManager.downloadFile(file_url,download_dir,filename);
                                }else{
                                    NodeManager.vbsEditFile(download_dir, filename);
                                } 
                            }
                        )
                    }else{
                        NodeManager.downloadFile(file_url,download_dir,filename);
                    }
                })
            }else{
                // 新建路径并下载附件到本地
                fs.mkdir(download_dir,function(err){
                    if (err) {
                        throw err;
                    }else{
                        NodeManager.downloadFile(file_url,download_dir,filename);
                    }
                })
            }
        })
    })
}
