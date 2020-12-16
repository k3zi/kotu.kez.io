import { withRouter } from "react-router";
import React, { useState } from 'react';
import ReactDOM from 'react-dom';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Container from 'react-bootstrap/Container';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import OverlayTrigger from 'react-bootstrap/OverlayTrigger';
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed'
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';
import Tooltip from 'react-bootstrap/Tooltip';
import YouTube from 'react-youtube';

import AddTargetLanguageModal from "./AddTargetLanguageModal";
import InviteUserModal from "./InviteUserModal";

const CustomMenu = React.forwardRef(({ children, style, className, 'aria-labelledby': labeledBy }, ref) => {
    const [value, setValue] = useState('');
    return (
        <div ref={ref} style={style} className={className} aria-labelledby={labeledBy}>
            <Form.Control autoFocus className="mx-3 my-2 w-auto" placeholder="Type to filter..." onChange={(e) => setValue(e.target.value)}   value={value} />
            <ul className="list-unstyled my-0">
                {React.Children.toArray(children).filter(child => !value || child.props.children.toLowerCase().startsWith(value))}
            </ul>
        </div>
    );
});

class ContentEditable extends React.Component {

    getTextSelection(editor) {
        const selection = window.getSelection();
        if (selection != null && selection.rangeCount > 0) {
            const range = selection.getRangeAt(0);

            return {
                start: this.getTextLength(editor, range.startContainer, range.startOffset),
                end: this.getTextLength(editor, range.endContainer, range.endOffset)
            };
        } else {
            return null;
        };
    }

    getTextLength(parent, node, offset) {
        if (!node) { return 0; }
        let textLength = 0;
        if (node && node.nodeName == '#text') {
            textLength += offset;
        } else {
            for (var i = 0; i < offset; i++) {
                textLength += this.getNodeTextLength(node.childNodes[i]);
            }
        }

        if (node != parent) {
            textLength += this.getTextLength(parent, node.parentNode, this.getNodeOffset(node));
        }

        return textLength;
    }

    getNodeTextLength(node) {
        let textLength = 0;
        if (node && node.nodeName == 'BR')
            textLength = 1;
        else if (node && node.nodeName == '#text')
            textLength = node.nodeValue.length;
        else if (node && node.childNodes != null)
            for (var i = 0; i < node.childNodes.length; i++)
                textLength += this.getNodeTextLength(node.childNodes[i]);

        return textLength;
    }

    getNodeOffset(node) {
        return node == null ? -1 : 1 + this.getNodeOffset(node.previousSibling);
    }

    getDOMNode() {
        return ReactDOM.findDOMNode(this);
    }

    componentDidMount() {
        this.ces = Math.random();
        const self = this;
        this.getDOMNode().addEventListener("selectstart", (e) => {
            const target = e.target;
            setTimeout(() => {
                if (window.getSelection()) {
                    function check() {
                        setTimeout(() => {
                            const selection = window.getSelection();
                            if (selection.baseNode.isEqualNode(target)) {
                                self.emitChange();
                                check();
                            }
                        }, 50);
                    }

                    check();
                }
                self.emitChange();
            }, 50);
        });
    }

    shouldComponentUpdate(nextProps) {
        return this.contentFromProps(nextProps) !== this.currentContent();
    }

    componentDidUpdate() {
        if (this.contentFromProps(this.props) !== this.currentContent()) {
           this.setCurrentContent(this.contentFromProps(this.props));
        }
    }

    isUsingHTML() {
        return !!this.props.html;
    }

    currentContent() {
        return this.isUsingHTML() ? this.getDOMNode().innerHTML : this.getDOMNode().innerText;
    }

    setCurrentContent(content) {
        if (this.isUsingHTML()) {
            this.getDOMNode().innerHTML = content;
        } else {
            this.getDOMNode().innerText = content;
        }
    }

    contentFromProps(props) {
        return props.html || props.value;
    }

    emitChange() {
        const node = this.getDOMNode();
        let value = node.innerText;
        const selection = this.getTextSelection(node);
        const selectionStart = selection ? selection.start : null;
        const selectionEnd = selection ? selection.end : null
        if (!this.isUsingHTML() && this.props.onChange && (value !== this.lastText || selectionStart !== this.lastSelectionStart || selectionEnd !== this.lastSelectionEnd)) {
            this.props.onChange({
                target: {
                    value,
                    selectionStart,
                    selectionEnd
                }
            });
        }

        if (this.isUsingHTML() && this.props.onHTMLClick) {
            const text = this.props.onHTMLClick();
            node.innerText = text;
            value = text;
            this.props.html = null;
        }

        this.lastText = value;
        this.lastSelectionStart = selectionStart;
        this.lastSelectionEnd = selectionEnd;
    }

    render() {
        return <div {...this.props} data-ces={this.ces} onInput={() => this.emitChange()} onBlur={() => this.emitChange()} onFocus={() => this.emitChange()} contentEditable>
            {this.props.html || this.props.value || ""}
        </div>;
    }

}

class Project extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            project: null,
            fragments: [],
            selectedBaseTranslation: null,
            selectedTargetTranslation: null,
            showAddTargetLanguageModal: false,
            showInviteUserModal: false,
            videoDuration: 0,
            currentTime: 0,
            baseLanguageText: "",
            targetLanguageText: "",
            player: null,
            updateQueue: [],
            isSubmittingUpdate: false,
            connectionID: null,
            color: null,
            isReady: false,
            otherUsers: []
        };
        this.ws = null;
    }

    componentDidMount() {
        this.loadProject();
        this.setupSocket();
    }

    setupSocket() {
        const id = this.props.match.params.id;
        const self = this;
        this.ws = new WebSocket(`ws://${window.location.host}/api/transcription/project/${id}/socket`);

       this.ws.onmessage = (evt) => {
           const message = JSON.parse(evt.data);
           const name = message.name;
           const data = message.data;
           if (name === "hello") {
               this.setState({ isReady: true, color: data.color, connectionID: data.id });
           } else if (name === "usersList") {
               for (let fragment of this.state.fragments) {
                   for (let subtitle of fragment.subtitles) {
                       subtitle.html = null;
                   }
               }
               for (let user of data) {
                   if (user.edit) {
                       let subtitle = this.state.fragments.map(f => f.subtitles.filter(s => s.id === user.edit.subtitleID)[0]).filter(s => s)[0];
                       if (subtitle) {
                           subtitle.text = user.edit.lastText;
                           if (user.edit.selectionStart != null && user.edit.selectionEnd != null && user.edit.selectionStart != user.edit.selectionEnd) {
                               subtitle.html = `${subtitle.text.slice(0, user.edit.selectionEnd)}</mark-${user.color}>${subtitle.text.slice(user.edit.selectionEnd)}`;
                               subtitle.html = `${subtitle.html.slice(0, user.edit.selectionStart)}<mark-${user.color}>${subtitle.html.slice(user.edit.selectionStart)}`;
                           } else if (user.edit.selectionStart != null) {
                               subtitle.html = `${subtitle.text.slice(0, user.edit.selectionStart)}<span class="fake-caret fake-caret-${user.color}"></span>${subtitle.text.slice(user.edit.selectionStart)}`;
                           } else {
                               subtitle.html = null;
                           }
                       }
                   }
               }
               this.setState({ otherUsers: data, fragments: this.state.fragments });
               console.log(data);
           } else if (name === "updateSubtitle") {
               if (this.state.focusedSubtitle && data.id === this.state.focusedSubtitle.id) {
                   document.activeElement.blur();
                   this.setState({ focusedSubtitle: null });
               }
           } else if (name === "newSubtitle") {
               for (let fragment of this.state.fragments) {
                   if (fragment.id === data.fragment.id) {
                       fragment.subtitles.push(data);
                       break;
                   }
               }
               this.setState({ fragments: this.state.fragments });
               console.log(message);
           } else if (name === "newFragment") {
               const fragments = this.state.fragments;
               fragments.push(data);
               this.setState({ fragments });
           }
       };

       this.ws.onclose = () => {
           this.setState({ isReady: false });
           setTimeout(function() {
               self.setupSocket();
           }, 1000);
       };
    }

    async loadProject(targetTranslation) {
        const id = this.props.match.params.id;
        const response = await fetch(`/api/transcription/project/${id}`);
        let selectedBaseTranslation = this.state.selectedBaseTranslation;
        let selectedTargetTranslation = targetTranslation || this.state.selectedTargetTranslation;
        if (response.ok) {
            const project = await response.json();
            selectedBaseTranslation = project.translations.filter(t => selectedBaseTranslation && t.id == selectedBaseTranslation.id)[0] || project.translations.filter(t => t.isOriginal)[0];
            selectedTargetTranslation = project.translations.filter(t => selectedTargetTranslation && t.id == selectedTargetTranslation.id)[0];
            this.setState({
                project,
                fragments: project.fragments,
                selectedBaseTranslation,
                selectedTargetTranslation
            });
        }
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    toggleAddTargetLanguageModal(show) {
        this.setState({
            showAddTargetLanguageModal: show
        });
    }

    toggleInviteUserModal(show) {
        this.setState({
            showInviteUserModal: show
        });
    }

    async addedNewTargetTranslation(translation) {
        await this.loadProject(translation);
        this.toggleAddTargetLanguageModal(false);
    }

    videoOnReady(e) {
        this.setState({
            videoDuration: e.target.getDuration(),
            player: e.target
        });

        e.target.pauseVideo();
        e.target.seekTo(this.nextStartTime());
        e.target.pauseVideo();
    }

    onPause(e) {
        this.setState({ currentTime: e.target.getCurrentTime() });
    }

    nextStartTime() {
        return this.state.fragments.length > 0 ? this.state.fragments[this.state.fragments.length - 1].endTime : 0;
    }

    formatTime(seconds) {
        if (this.state.videoDuration > 60 * 60) {
            return new Date(seconds * 1000).toISOString().substr(11, 8);
        } else {
            return new Date(seconds * 1000).toISOString().substr(14, 5);
        }
    }

    async addFragment() {
        if (!this.state.selectedBaseTranslation.isOriginal || this.state.baseLanguageText.trim().length == 0) {
            return;
        }

        const data = {
            baseText: this.state.baseLanguageText.trim(),
            baseTranslationID: this.state.selectedBaseTranslation.id,
            targetText: this.state.targetLanguageText.trim(),
            targetTranslationID: this.state.selectedTargetTranslation ? this.state.selectedTargetTranslation.id : null,
            startTime: this.nextStartTime(),
            endTime: this.state.currentTime
        };

        const response = await fetch(`/api/transcription/project/${this.state.project.id}/fragment/create`, {
            method: "POST",
            body: JSON.stringify(data),
            headers: {
                "Content-Type": "application/json"
            }
        });
         if (response.ok) {
             await this.loadProject();
             this.setState({
                 baseLanguageText: "",
                 targetLanguageText: ""
             });
             this.bottomOfFragments.scrollIntoView({ behavior: "smooth" });
             this.ws.send(JSON.stringify({
                 name: 'newFragment',
                 data: await response.json(),
                 connectionID: this.state.connectionID
             }));
         } else {
             const result = await response.json();
             this.setState({
                 didError: result.error,
                 message: result.reason
             });
         }
    }

    async updateSubtitle(fragment, translation, text) {
        this.setState({
            isSubmittingUpdate: true
        });
        let subtitle = fragment.subtitles.filter(s => s.translation.id == translation.id)[0];
        if (!subtitle) {
            const response = await fetch(`/api/transcription/project/${this.state.project.id}/subtitle/create`, {
                method: "POST",
                body: JSON.stringify({
                    translationID: translation.id,
                    fragmentID: fragment.id,
                    text
                 }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
        } else {
            await fetch(`/api/transcription/project/${this.state.project.id}/subtitle/${subtitle.id}`, {
                method: "PUT",
                body: JSON.stringify({ text }),
                headers: {
                    "Content-Type": "application/json"
                }
            });
        }

        const updateQueue = this.state.updateQueue;
        if (updateQueue.length > 0) {
            const next = updateQueue.shift();
            this.setState({ updateQueue });
            await this.updateSubtitle(next.fragment, next.translation, next.text);
        } else {
            this.setState({
                isSubmittingUpdate: false
            });
        }
    }

    async addToUpdateQueue(fragment, translation, target) {
        await this.didFocusOn(fragment, translation, target);
        const text = target.value;
        const updateQueue = this.state.updateQueue;
        updateQueue.push({ fragment, translation, text });
        if (!this.state.isSubmittingUpdate) {
            const next = updateQueue.shift();
            this.setState({ updateQueue });
            this.updateSubtitle(next.fragment, next.translation, next.text);
        }
    }

    baseSubtitleForFragment(fragment) {
        if (!this.state.selectedBaseTranslation) {
            return null;
        }

        return fragment.subtitles.filter(s => s.translation.id == this.state.selectedBaseTranslation.id)[0];
    }

    targetSubtitleForFragment(fragment) {
        if (!this.state.selectedTargetTranslation) {
            return null;
        }

        return fragment.subtitles.filter(s => s.translation.id == this.state.selectedTargetTranslation.id)[0];
    }

    async didFocusOn(fragment, translation, target) {
        let subtitle;
        if (fragment || translation) {
            subtitle = fragment.subtitles.filter(s => s.translation.id == translation.id)[0];
        }

        if (this.state.focusedSubtitle && (!subtitle || this.state.focusedSubtitle.id != subtitle.id)) {
            this.setState({ focusedSubtitle: null });
            this.ws.send(JSON.stringify({
                name: 'blurSubtitle',
                data: this.state.focusedSubtitle,
                connectionID: this.state.connectionID
            }));
        }

        if (!fragment || !translation) {
            return;
        }

        if (subtitle) {
            subtitle.text = target.value;
            subtitle.html = null;
        } else if (!subtitle) {
            const response = await fetch(`/api/transcription/project/${this.state.project.id}/subtitle/create`, {
                method: "POST",
                body: JSON.stringify({
                    translationID: translation.id,
                    fragmentID: fragment.id,
                    text: ""
                 }),
                headers: {
                    "Content-Type": "application/json"
                }
            });

            if (!response.ok) return;
            subtitle = await response.json();
            fragment.subtitles.push(subtitle);
            this.setState({ fragments: this.state.fragments });
            this.ws.send(JSON.stringify({
                name: 'newSubtitle',
                data: subtitle,
                connectionID: this.state.connectionID
            }));
        }

        subtitle.selectionStart = target.selectionStart;
        subtitle.selectionEnd = target.selectionEnd;

        this.setState({
            focusedSubtitle: subtitle
        });

        this.ws.send(JSON.stringify({
            name: 'updateSubtitle',
            data: subtitle,
            connectionID: this.state.connectionID
        }));
    }

    onHTMLClick(subtitle) {
        subtitle.html = null;
        return subtitle.text;
    }

    render() {
        return (
            <div>
                {(!this.state.project || !this.state.isReady) && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.project && this.state.isReady  && <div>
                    <Row className="mb-4">
                        <Col>
                            <h2 className="display-4">{this.state.project.name}</h2>
                        </Col>
                        <Col xs="auto">
                            <p className="bg-secondary text-white p-2 rounded">
                                <strong>Owner</strong>: {this.state.project.owner.username}
                                <br />
                                <strong>Video ID</strong>: {this.state.project.youtubeID}
                            </p>
                            <Button variant="primary" className="float-right" onClick={() => this.toggleInviteUserModal(true)}>Invite User</Button>
                        </Col>
                    </Row>
                    <Form.Row className="align-items-center justify-content-center" inline>
                        <Col sm={4}>
                            <InputGroup>
                                <DropdownButton as={InputGroup.Prepend} variant="outline-secondary" title="Base Language" id="input-group-dropdown-1">
                                    {this.state.project.translations.map(translation => {
                                        return <Dropdown.Item active={this.state.selectedBaseTranslation && translation.id == this.state.selectedBaseTranslation.id} onSelect={() => this.setState({ selectedBaseTranslation: translation })} href="#">{translation.language.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                                <Form.Control value={this.state.selectedBaseTranslation.language.name} readOnly />
                            </InputGroup>
                        </Col>
                        <i className="bi bi-arrow-bar-right"></i>
                        <Col sm={4}>
                            <InputGroup>
                                <DropdownButton as={InputGroup.Prepend} variant="outline-secondary" title="Target Language" id="input-group-dropdown-1">
                                    <Dropdown.Item active={!this.state.selectedBaseTranslation}  onSelect={() => this.setState({ selectedTargetTranslation: null })}>None</Dropdown.Item>
                                    <Dropdown.Divider />
                                    {this.state.project.translations.map(translation => {
                                        return <Dropdown.Item active={this.state.selectedTargetTranslation && translation.id == this.state.selectedTargetTranslation.id} onSelect={() => this.setState({ selectedTargetTranslation: translation })}>{translation.language.name}</Dropdown.Item>;
                                    })}
                                    <Dropdown.Divider />
                                    <Dropdown.Item onSelect={() => this.toggleAddTargetLanguageModal(true)}>Add Translation</Dropdown.Item>
                                </DropdownButton>
                                <Form.Control value={this.state.selectedTargetTranslation ? this.state.selectedTargetTranslation.language.name : "(None)"} readOnly />
                            </InputGroup>
                        </Col>
                    </Form.Row>
                    <hr />
                    <Container className="py-0">
                        <Row>
                            <span className="align-self-center">
                                Helpers:
                            </span>
                            <Col>
                                {this.state.otherUsers.map((u, i) => {
                                    return <OverlayTrigger key={i} placement="bottom" overlay={<Tooltip>{u.username}</Tooltip>}>
                                        <Spinner className="mr-2" animation="grow" variant={u.color} />
                                    </OverlayTrigger>;
                                })}
                            </Col>
                            <Col xs="auto">
                                <OverlayTrigger placement="bottom" overlay={<Tooltip>(You)</Tooltip>}>
                                    <Spinner className="px-2" xs="auto" animation="grow" variant={this.state.color} />
                                </OverlayTrigger>
                            </Col>
                        </Row>
                    </Container>
                    <hr />
                    <Container className="py-0" fluid>
                        <Row>
                            <Col className="col-6">
                                <div className="overflow-auto max-vh-50">
                                    <Container className="mb-0 py-0" fluid>
                                        {this.state.fragments.map((fragment, id) => {
                                            return <div key={id}>
                                                <hr className="row" style={{"margin-block-start": 0, "margin-block-end": 0}} />
                                                <Row className="bg-light py-3 align-items-center">
                                                    <Col xs="auto" className="text-center align-self-center">
                                                        <Badge onClick={() => this.state.player.seekTo(fragment.startTime)} variant="secondary-inverted">{this.formatTime(fragment.startTime)}</Badge>
                                                    </Col>
                                                    <Col className="px-0">
                                                        <ContentEditable onHTMLClick={() => this.onHTMLClick(this.baseSubtitleForFragment(fragment))} value={this.baseSubtitleForFragment(fragment).text} html={this.baseSubtitleForFragment(fragment).html} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedBaseTranslation, e.target)} className={`form-control h-auto text-break no-box-shadow caret-${this.state.color} border-focus-${this.state.color} ${this.state.otherUsers.filter(o => o.edit && o.edit.subtitleID === this.baseSubtitleForFragment(fragment).id).map(o => `border-${o.color}`)[0] || ''}`} />
                                                        {this.state.selectedTargetTranslation && <ContentEditable onHTMLClick={() => this.onHTMLClick(this.targetSubtitleForFragment(fragment))} value={this.targetSubtitleForFragment(fragment) ? this.targetSubtitleForFragment(fragment).text : ""} html={this.targetSubtitleForFragment(fragment) ? this.targetSubtitleForFragment(fragment).html : null} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedTargetTranslation, e.target)}  className={`form-control h-auto text-break mt-2 no-box-shadow caret-${this.state.color} border-focus-${this.state.color} ${this.state.otherUsers.filter(o => o.edit && this.targetSubtitleForFragment(fragment) && o.edit.subtitleID === this.targetSubtitleForFragment(fragment).id).map(o => `border-${o.color}`)[0] || ''}`} />}
                                                    </Col>
                                                    <Col xs="auto" className="text-center align-self-center">
                                                        <Badge onClick={() => this.state.player.seekTo(fragment.endTime)} variant="secondary-inverted">{this.formatTime(fragment.endTime)}</Badge>
                                                    </Col>
                                                </Row>
                                            </div>;
                                        })}
                                        <div style={{ float:"left", clear: "both" }}
                                            ref={(el) => { this.bottomOfFragments = el; }}>
                                        </div>
                                    </Container>
                                </div>

                                <Container className="mb-2 py-0" fluid>
                                    <hr className="row" style={{"margin-block-start": 0, "margin-block-end": 0}} />
                                    <Row className="bg-white py-3 align-items-center">
                                        <Col xs="auto" className="text-center align-self-center">
                                            <Badge onClick={() => this.state.player.seekTo(this.nextStartTime())} variant="secondary-inverted">{this.formatTime(this.nextStartTime())}</Badge>
                                        </Col>
                                        <Col className="px-0">
                                            <ContentEditable value={this.state.baseLanguageText} onFocus={(e) => this.didFocusOn(null, null, null)} onChange={(e) => this.setState({ baseLanguageText: e.target.value })} className={`form-control h-auto text-break no-box-shadow caret-${this.state.color} border-focus-${this.state.color}`} />
                                            {this.state.selectedTargetTranslation && <ContentEditable value={this.state.targetLanguageText} onFocus={(e) => this.didFocusOn(null, null, null)} onChange={(e) => this.setState({ targetLanguageText: e.target.value })}  className={`form-control h-auto text-break mt-2 no-box-shadow caret-${this.state.color} border-focus-${this.state.color}`} />}
                                        </Col>
                                        <Col xs="auto" className="text-center align-self-center">
                                            <Badge variant="secondary-inverted">{this.formatTime(this.state.currentTime)}</Badge>
                                        </Col>
                                    </Row>
                                    <hr className="row" style={{"margin-block-start": 0, "margin-block-end": 0}} />
                                </Container>

                                {this.state.selectedBaseTranslation && !this.state.selectedBaseTranslation.isOriginal && <Alert className="mt-1 mb-2" variant="secondary">Switch to the original transcription to add more fragments.</Alert>}
                                <Button variant="primary" onClick={() => this.addFragment()} disabled={!this.state.selectedBaseTranslation || !this.state.selectedBaseTranslation.isOriginal || !this.state.baseLanguageText || this.state.baseLanguageText.trim().length == 0} block>Add Fragment</Button>
                            </Col>
                            <Col>
                                <ResponsiveEmbed aspectRatio="16by9">
                                    <YouTube videoId={this.state.project.youtubeID} onReady={(e) => this.videoOnReady(e)} onPause ={(e) => this.onPause(e)} opts={{ playerVars: { modestbranding: 1 }}}/>
                                </ResponsiveEmbed>
                            </Col>
                        </Row>
                    </Container>
                    <AddTargetLanguageModal project={this.state.project} show={this.state.showAddTargetLanguageModal} onHide={() => this.toggleAddTargetLanguageModal(false)} didCancel={() => this.toggleAddTargetLanguageModal(false)} onFinish={(t) => this.addedNewTargetTranslation(t)} />
                    <InviteUserModal project={this.state.project} show={this.state.showInviteUserModal} onHide={() => this.toggleInviteUserModal(false)} didCancel={() => this.toggleInviteUserModal(false)} onFinish={() => this.toggleInviteUserModal(false)} />
                </div>}
            </div>
        )
    }
}

export default withRouter(Project);
