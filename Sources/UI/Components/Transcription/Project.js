import { withRouter } from 'react-router';
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
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed';
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';
import Tooltip from 'react-bootstrap/Tooltip';
import YouTube from 'react-youtube';

import AddTargetLanguageModal from './AddTargetLanguageModal';
import AutoSyncModal from './AutoSyncModal';
import ContentEditable from './../Common/ContentEditable';
import InviteUserModal from './InviteUserModal';
import ShareURLModal from './ShareURLModal';
import SystemImportModal from './SystemImportModal';
import EditFragmentModal from './EditFragmentModal';
import FragmentEmbedModal from './FragmentEmbedModal';

import UserContext from './../Context/User';

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
            showShareURLModal: false,
            showEditFragmentModal: null,
            showAutoSyncModal: false,
            showSystemImportModal: false,
            showFragmentEmbed: null,
            videoDuration: 0,
            currentTime: 0,
            baseLanguageText: '',
            targetLanguageText: '',
            player: null,
            updateQueue: [],
            isSubmittingUpdate: false,
            connectionID: null,
            color: null,
            isReady: false,
            otherUsers: [],
            fragmentListTopScroll: 0.0,
            fragmentListBottomScroll: 0.0,
            commentListTopScroll: 0.0,
            commentListBottomScroll: 0.0,
            message: '',
            messages: [],
            canWrite: false
        };
        this.ws = null;
    }

    componentDidMount() {
        this.setupSocket();
    }

    getShareHash(shouldEncode) {
        const urlParams = new URLSearchParams(window.location.search);
        const shareHash = urlParams.get('shareHash') || '';
        return shouldEncode ? encodeURIComponent(shareHash) : shareHash;
    }

    sortFragments(fragments) {
        return fragments.sort((a, b) => a.startTime - b.startTime);
    }

    setupSocket() {
        const id = this.props.match.params.id;
        const self = this;
        this.ws = new WebSocket(`${location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/api/transcription/project/${id}/socket?shareHash=${this.getShareHash(true)}`);

        this.ws.onerror = (err) => {
            console.log(err);
        };

        this.ws.onmessage = (evt) => {
            const message = JSON.parse(evt.data);
            const name = message.name;
            const data = message.data;
            if (name === 'hello') {
                let selectedBaseTranslation = this.state.selectedBaseTranslation;
                let selectedTargetTranslation = this.state.selectedTargetTranslation;

                const project = data.project;
                selectedBaseTranslation = project.translations.filter(t => selectedBaseTranslation && t.id == selectedBaseTranslation.id)[0] || project.translations.filter(t => t.isOriginal)[0];
                selectedTargetTranslation = project.translations.filter(t => selectedTargetTranslation && t.id == selectedTargetTranslation.id)[0];
                this.setState({
                    project,
                    fragments: this.sortFragments(project.fragments),
                    selectedBaseTranslation,
                    selectedTargetTranslation,
                    isReady: true,
                    color: data.color,
                    connectionID: data.id,
                    canWrite: data.canWrite,
                    messages: data.messages
                });
                setTimeout(() => {
                    this.bottomOfComments.parentNode.parentNode.scrollTop = this.bottomOfComments.offsetTop;
                }, 500);
            } else if (name === 'usersList') {
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
            } else if (name === 'updateSubtitle') {
                if (this.state.focusedSubtitle && data.id === this.state.focusedSubtitle.id) {
                    document.activeElement.blur();
                    this.setState({ focusedSubtitle: null });
                }
            } else if (name === 'newSubtitle') {
                for (let fragment of this.state.fragments) {
                    if (fragment.id === data.fragment.id && fragment.subtitles.filter(s => s.id === data.id).length === 0) {
                        fragment.subtitles.push(data);
                        break;
                    }
                }
                this.setState({ fragments: this.state.fragments });
            } else if (name === 'newFragment') {
                const fragments = this.state.fragments.filter(f => f.id !== data.id);
                fragments.push(data);
                this.setState({ fragments: this.sortFragments(fragments) });
            } else if (name === 'deleteFragment') {
                const fragments = this.state.fragments.filter(f => f.id != data.id);
                this.setState({ fragments });
            } else if (name === 'newTranslation') {
                this.state.project.translations.push(data);
                this.setState({ project: this.state.project });
            } else if (name === 'message') {
                this.state.messages.push(data);
                this.setState({ messages: this.state.messages });

                setTimeout(() => {
                    this.bottomOfComments.scrollIntoView({ behavior: 'smooth' });
                }, 200);
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
        const response = await fetch(`/api/transcription/project/${id}`, {
            headers: {
                'X-Kotu-Share-Hash': this.getShareHash(false)
            }
        });
        let selectedBaseTranslation = this.state.selectedBaseTranslation;
        let selectedTargetTranslation = targetTranslation || this.state.selectedTargetTranslation;
        if (response.ok) {
            const project = await response.json();
            selectedBaseTranslation = project.translations.filter(t => selectedBaseTranslation && t.id == selectedBaseTranslation.id)[0] || project.translations.filter(t => t.isOriginal)[0];
            selectedTargetTranslation = project.translations.filter(t => selectedTargetTranslation && t.id == selectedTargetTranslation.id)[0];
            this.setState({
                project,
                fragments: this.sortFragments(project.fragments),
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

    toggleShareURLModal(show) {
        this.setState({
            showShareURLModal: show
        });
    }

    toggleShowEditFragmentModal(fragment) {
        this.setState({
            showEditFragmentModal: fragment
        });
    }

    toggleShowAutoSyncModal(show) {
        this.setState({
            showAutoSyncModal: show
        });
        if (!show) {
            this.loadProject();
        }
    }

    toggleShowSystemImportModal(show) {
        this.setState({
            showSystemImportModal: show
        });
    }

    async addedNewTargetTranslation(translation) {
        await this.loadProject(translation);
        this.toggleAddTargetLanguageModal(false);
        this.ws.send(JSON.stringify({
            name: 'newTranslation',
            data: translation,
            connectionID: this.state.connectionID
        }));
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
            method: 'POST',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json',
                'X-Kotu-Share-Hash': this.getShareHash(false)
            }
        });
        if (response.ok) {
            await this.loadProject();
            this.setState({
                baseLanguageText: '',
                targetLanguageText: ''
            });
            this.bottomOfFragments.scrollIntoView({ behavior: 'smooth' });
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
        if (subtitle && this.state.canWrite) {
            await fetch(`/api/transcription/project/${this.state.project.id}/subtitle/${subtitle.id}`, {
                method: 'PUT',
                body: JSON.stringify({ text }),
                headers: {
                    'Content-Type': 'application/json',
                    'X-Kotu-Share-Hash': this.getShareHash(false)
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
                method: 'POST',
                body: JSON.stringify({
                    translationID: translation.id,
                    fragmentID: fragment.id,
                    text: ''
                }),
                headers: {
                    'Content-Type': 'application/json',
                    'X-Kotu-Share-Hash': this.getShareHash(false)
                }
            });

            if (!response.ok) return this.handleError(response);
            subtitle = await response.json();
            fragment.subtitles.push(subtitle);
            this.setState({ fragments: this.sortFragments(this.state.fragments) });
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

    async handleError(response) {

    }

    sendMessage() {
        const message = this.state.message;
        this.ws.send(JSON.stringify({
            name: 'message',
            data: { text: message },
            connectionID: this.state.connectionID
        }));
        this.setState({ message: '' });
    }

    sendMessageEnter(e) {
        if (e.keyCode == 13) {
            e.preventDefault();
            if (this.state.message.length > 0) {
                this.sendMessage();
            }
        }
    }

    async deleteFragment(fragment) {
        const response = await fetch(`/api/transcription/project/${this.state.project.id}/fragment/${fragment.id}`, {
            method: 'DELETE',
            headers: {
                'X-Kotu-Share-Hash': this.getShareHash(false)
            }
        });

        if (!response.ok) return this.handleError(response);
        const fragments = this.state.fragments.filter(f => f.id != fragment.id);
        this.setState({ fragments });
        this.ws.send(JSON.stringify({
            name: 'deleteFragment',
            data: fragment,
            connectionID: this.state.connectionID
        }));
    }

    async showFragmentEmbed(fragment) {
        this.setState({ showFragmentEmbed: fragment });
    }

    onHTMLClick(subtitle) {
        subtitle.html = null;
        return subtitle.text;
    }

    onFragmentListScroll(element) {
        if (!element) return;
        let bottom = element.scrollHeight - element.clientHeight;
        let fragmentListTopScroll = Math.min(1, element.scrollTop / 127);
        let fragmentListBottomScroll = Math.min(1, (bottom - element.scrollTop) / 127);
        if (this.state.fragmentListTopScroll != fragmentListTopScroll || this.state.fragmentListBottomScroll != fragmentListBottomScroll) {
            this.setState({ fragmentListTopScroll, fragmentListBottomScroll});
        }
    }

    onCommentListScroll(element) {
        if (!element) return;
        let bottom = element.scrollHeight - element.clientHeight;
        let commentListTopScroll = Math.min(1, element.scrollTop / 127);
        let commentListBottomScroll = Math.min(1, (bottom - element.scrollTop) / 127);
        if (this.state.commentListTopScroll != commentListTopScroll || this.state.commentListBottomScroll != commentListBottomScroll) {
            this.setState({ commentListTopScroll, commentListBottomScroll });
        }
    }

    renderExport(side) {
        return (
            <>
                <hr className={side === 'left' ? 'd-none d-lg-block' : 'd-none'} />
                <h4 className={`${side === 'left' ? 'd-none d-lg-block' : 'd-block d-lg-none mt-2 mt-lg-0'} text-center mt-3}`}>Export</h4>
                <Table className={side === 'left' ? 'd-none d-lg-table mb-0' : 'd-table d-lg-none mb-0'} bordered responsive="sm">
                    <thead>
                        <tr>
                            <th className="text-center">Base ({this.state.selectedBaseTranslation.language.name})</th>
                            {this.state.selectedTargetTranslation && <th className="text-center">Target ({this.state.selectedTargetTranslation.language.name})</th>}
                        </tr>
                    </thead>
                    <tbody>
                        {['srt'].map((ext, i) => {
                            return <tr key={i}>
                                <td>
                                    <Button className='col-12' href={`/api/transcription/project/${this.state.project.id}/translation/${this.state.selectedBaseTranslation.id}/download/${ext}?shareHash=${this.getShareHash(true)}`} variant="outline-secondary" block download>
                                        Download .{ext}
                                    </Button>
                                </td>
                                {this.state.selectedTargetTranslation && <td>
                                    <Button className='col-12' href={`/api/transcription/project/${this.state.project.id}/translation/${this.state.selectedTargetTranslation.id}/download/${ext}?shareHash=${this.getShareHash(true)}`} variant="outline-secondary" block download>
                                        Download .{ext}
                                    </Button>
                                </td>}
                            </tr>;
                        })}
                    </tbody>
                </Table>
            </>
        );
    }

    render() {
        return (
            <div>
                {(!this.state.project || !this.state.isReady) && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.project && this.state.isReady  && <div>
                    <Row className="mb-4">
                        <Col xs={12} md={6}>
                            <h2 className="display-4">{this.state.project.name}</h2>
                        </Col>
                        <Col xs={12} md={6}>
                            <p className="bg-secondary text-white p-2 rounded">
                                <strong>Owner</strong>: {this.state.project.owner.username}
                                <br />
                                <strong>Video ID</strong>: {this.state.project.youtubeID}
                            </p>
                            {this.state.canWrite && <div className='d-flex justify-content-between mt-2'>
                                <Button variant='primary' className='col' onClick={() => this.toggleShareURLModal(true)}>Share URL</Button>
                                <Button variant='primary' className='col ms-2' onClick={() => this.toggleInviteUserModal(true)}>Invite User</Button>
                                {this.state.fragments.length === 0 && <Button variant='primary' className='col ms-2' onClick={() => this.toggleShowAutoSyncModal(true)}>Auto Sync</Button>}
                                {this.state.fragments.length > 0 && this.context && this.context.permissions.includes('subtitles') && <Button variant='primary' className='col ms-2' onClick={() => this.toggleShowSystemImportModal(true)}>System Import</Button>}
                            </div>}
                        </Col>
                    </Row>
                    <Row className="align-items-center justify-content-center">
                        <Col xs={12} md={5}>
                            <InputGroup>
                                <DropdownButton variant="outline-secondary" title="Base Language" id="input-group-dropdown-1">
                                    {this.state.project.translations.map((translation, i) => {
                                        return <Dropdown.Item key={i} active={this.state.selectedBaseTranslation && translation.id == this.state.selectedBaseTranslation.id} onSelect={() => this.setState({ selectedBaseTranslation: translation })} href="#">{translation.language.name}</Dropdown.Item>;
                                    })}
                                </DropdownButton>
                                <Form.Control value={this.state.selectedBaseTranslation.language.name} readOnly />
                            </InputGroup>
                        </Col>
                        <div className="col-12 d-block d-md-none"></div>
                        <i className="bi bi-arrow-bar-right text-center w-auto px-0"></i>
                        <div className="col-12 d-block d-md-none"></div>
                        <Col xs={12} md={5}>
                            <InputGroup>
                                <DropdownButton variant="outline-secondary" title="Target Language" id="input-group-dropdown-1">
                                    <Dropdown.Item key={-1} active={!this.state.selectedBaseTranslation}  onSelect={() => this.setState({ selectedTargetTranslation: null })}>None</Dropdown.Item>
                                    <Dropdown.Divider />
                                    {this.state.project.translations.map((translation, i) => {
                                        return <Dropdown.Item key={i} active={this.state.selectedTargetTranslation && translation.id == this.state.selectedTargetTranslation.id} onSelect={() => this.setState({ selectedTargetTranslation: translation })}>{translation.language.name}</Dropdown.Item>;
                                    })}
                                    <Dropdown.Divider />
                                    <Dropdown.Item key={-2} onSelect={() => this.toggleAddTargetLanguageModal(true)}>Add Translation</Dropdown.Item>
                                </DropdownButton>
                                <Form.Control value={this.state.selectedTargetTranslation ? this.state.selectedTargetTranslation.language.name : '(None)'} readOnly />
                            </InputGroup>
                        </Col>
                    </Row>
                    <hr className="mb-2" />
                    <Container className="py-0">
                        <Row>
                            <Col>
                                {this.state.otherUsers.map((u, i) => {
                                    return <div className="d-inline-block text-center me-2" key={i}>
                                        <Spinner animation="grow" variant={u.color} />
                                        <br />
                                        <div className="bg-gray-200 text-secondary rounded px-2 py-0">{u.username}</div>
                                    </div>;
                                })}
                            </Col>
                            <Col xs="auto">
                                <div className="d-inline-block text-center">
                                    <Spinner className="px-2" xs="auto" animation="grow" variant={this.state.color} />
                                    <br />
                                    <div className="bg-gray-200 text-secondary rounded px-2 py-0">(You)</div>
                                </div>
                            </Col>
                        </Row>
                    </Container>
                    <hr className="mt-2" />
                    <Container className="py-0" fluid>
                        <Row>
                            <Col xs={12} md={6}>
                                <div className="position-relative">
                                    <div className="gutter-margin position-absolute w-100" style={{ height: '27px', pointerEvents: 'none', background: `linear-gradient(0deg, rgba(0, 0, 0, 0) 0%, rgba(127, 127, 127, ${this.state.fragmentListTopScroll * 0.27}) 100%)`, zIndex: '1', top: '0' }}></div>
                                    <div className="overflow-auto hide-scrollbar max-vh-75" onScroll={(e) => this.onFragmentListScroll(e.target)} ref={(r) => this.onFragmentListScroll(r)}>
                                        <Container className="mb-0 py-0" fluid>
                                            {this.state.fragments.map((fragment, id) => {
                                                return <div key={id}>
                                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                                    <Row className="bg-light py-3 align-items-center position-relative">
                                                        <span className="position-absolute" style={{ left: 0, top: 0, cursor: 'pointer', width: 'auto' }}>
                                                            {this.state.canWrite && this.state.selectedBaseTranslation.isOriginal && <a className='me-1' onClick={() => this.toggleShowEditFragmentModal(fragment)}><i className="bi bi-gear text-secondary"></i></a>}
                                                            <a download href={`/api/media/youtube/download?startTime=${fragment.startTime}&endTime=${fragment.endTime}&youtubeID=${this.state.project.youtubeID}`}><i className="bi bi-download text-info"></i></a>
                                                            <a className='ps-1' style={{ cursor: 'pointer' }} onClick={() => this.showFragmentEmbed(fragment)}><i className="bi bi-link-45deg text-info"></i></a>
                                                        </span>
                                                        <Col xs="auto" className="text-center align-self-center">
                                                            <Badge onClick={() => this.state.player.seekTo(fragment.startTime) && this.state.player.playVideo()} style={{ cursor: 'pointer' }} className="bg-secondary-inverted">{this.formatTime(fragment.startTime)}</Badge>
                                                        </Col>
                                                        <Col className="px-0">
                                                            <ContentEditable disabled={!this.state.canWrite} onHTMLClick={() => this.onHTMLClick(this.baseSubtitleForFragment(fragment))} value={this.baseSubtitleForFragment(fragment).text} html={this.baseSubtitleForFragment(fragment).html} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedBaseTranslation, e.target)} className={`form-control h-auto text-break no-box-shadow caret-${this.state.color} border-focus-${this.state.color} ${this.state.otherUsers.filter(o => o.edit && o.edit.subtitleID === this.baseSubtitleForFragment(fragment).id).map(o => `border-${o.color}`)[0] || ''}`} />
                                                            {this.state.selectedTargetTranslation && <ContentEditable disabled={!this.state.canWrite} onHTMLClick={() => this.onHTMLClick(this.targetSubtitleForFragment(fragment))} value={this.targetSubtitleForFragment(fragment) ? this.targetSubtitleForFragment(fragment).text : ''} html={this.targetSubtitleForFragment(fragment) ? this.targetSubtitleForFragment(fragment).html : null} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedTargetTranslation, e.target)}  className={`form-control h-auto text-break mt-2 no-box-shadow caret-${this.state.color} border-focus-${this.state.color} ${this.state.otherUsers.filter(o => o.edit && this.targetSubtitleForFragment(fragment) && o.edit.subtitleID === this.targetSubtitleForFragment(fragment).id).map(o => `border-${o.color}`)[0] || ''}`} />}
                                                        </Col>
                                                        <Col xs="auto" className="text-center align-self-center">
                                                            <Badge onClick={() => this.state.player.seekTo(fragment.endTime) && this.state.player.playVideo()} style={{ cursor: 'pointer' }} className='bg-secondary-inverted'>{this.formatTime(fragment.endTime)}</Badge>
                                                        </Col>
                                                        <span className="position-absolute" style={{ right: 0, top: 0, cursor: 'pointer', width: 'auto' }}>{this.state.canWrite && this.state.selectedBaseTranslation.isOriginal && <a onClick={() => this.deleteFragment(fragment)}><i className="bi bi-trash text-danger"></i></a>}</span>
                                                    </Row>
                                                </div>;
                                            })}
                                            <div style={{ float:'left', clear: 'both' }}
                                                ref={(el) => { this.bottomOfFragments = el; }}>
                                            </div>
                                        </Container>
                                    </div>
                                    <div className="gutter-margin position-absolute w-100" style={{ height: '27px', pointerEvents: 'none', background: `linear-gradient(0deg, rgba(127, 127, 127, ${this.state.fragmentListBottomScroll * 0.27}) 0%, rgba(0, 0, 0, 0) 100%)`, 'z-index': '1', 'bottom': '0' }}></div>
                                </div>

                                <Container className="mb-2 py-0" fluid>
                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                    {this.state.canWrite && <Row className="bg-white py-3 align-items-center">
                                        <Col xs="auto" className="text-center align-self-center">
                                            <Badge onClick={() => this.state.player.seekTo(this.nextStartTime()) && this.state.player.playVideo()} style={{ cursor: 'pointer' }} className="bg-secondary-inverted">{this.formatTime(this.nextStartTime())}</Badge>
                                        </Col>
                                        <Col className="px-0">
                                            <ContentEditable value={this.state.baseLanguageText} onFocus={(e) => this.didFocusOn(null, null, null)} onChange={(e) => this.setState({ baseLanguageText: e.target.value })} className={`form-control h-auto text-break no-box-shadow caret-${this.state.color} border-focus-${this.state.color}`} />
                                            {this.state.selectedTargetTranslation && <ContentEditable value={this.state.targetLanguageText} onFocus={(e) => this.didFocusOn(null, null, null)} onChange={(e) => this.setState({ targetLanguageText: e.target.value })}  className={`form-control h-auto text-break mt-2 no-box-shadow caret-${this.state.color} border-focus-${this.state.color}`} />}
                                        </Col>
                                        <Col xs="auto" className="text-center align-self-center">
                                            <Badge className="bg-secondary-inverted">{this.formatTime(Math.max(this.state.currentTime, this.nextStartTime()))}</Badge>
                                        </Col>
                                    </Row>}
                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                </Container>
                                {this.state.canWrite && <div className="d-grid gap-2">
                                    {this.state.selectedBaseTranslation && !this.state.selectedBaseTranslation.isOriginal && <Alert className="mt-1 mb-2" variant="secondary">Switch to the original transcription to add more fragments.</Alert>}
                                    <Button className='mb-2' variant="primary" onClick={() => this.addFragment()} disabled={!this.state.selectedBaseTranslation || !this.state.selectedBaseTranslation.isOriginal || !this.state.baseLanguageText || this.state.baseLanguageText.trim().length == 0}>Add Fragment</Button>
                                </div>}

                                {this.renderExport('left')}

                            </Col>

                            <Col xs={12} md={6}>
                                <ResponsiveEmbed aspectRatio="16by9">
                                    <YouTube videoId={this.state.project.youtubeID} onReady={(e) => this.videoOnReady(e)} onPause ={(e) => this.onPause(e)} opts={{ playerVars: { modestbranding: 1, fs: 0, playsinline: 1 }}} />
                                </ResponsiveEmbed>

                                {this.renderExport('right')}

                                <h4 className="text-center mt-2">Comments</h4>

                                <div className="position-relative">
                                    <div className="gutter-margin position-absolute w-100" style={{ height: '27px', pointerEvents: 'none', background: `linear-gradient(0deg, rgba(0, 0, 0, 0) 0%, rgba(127, 127, 127, ${this.state.commentListTopScroll * 0.27}) 100%)`, zIndex: '1', top: '0' }}></div>
                                    <div className="overflow-auto hide-scrollbar max-vh-75" onScroll={(e) => this.onCommentListScroll(e.target)} ref={(r) => this.onCommentListScroll(r)}>
                                        <Container className="mb-0 py-0" fluid>
                                            {this.state.messages.map((message, id) => {
                                                return <div key={id}>
                                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                                    <Row className="bg-light py-3 align-items-center position-relative">
                                                        <Col xs="auto" className="text-center align-self-center">
                                                            <div className="d-inline-block text-center me-2">
                                                                <Spinner animation="grow" variant={message.color} />
                                                                <br />
                                                                <div className="bg-gray-200 text-secondary rounded px-2 py-0">{message.username}</div>
                                                            </div>
                                                        </Col>
                                                        <Col className="ps-0 pe-3">
                                                            <ContentEditable disabled={true} value={message.text} className='form-control h-auto text-break no-box-shadow plaintext' />
                                                        </Col>
                                                    </Row>
                                                </div>;
                                            })}
                                            <div style={{ float:'left', clear: 'both' }}
                                                ref={(el) => { this.bottomOfComments = el; }}>
                                            </div>
                                        </Container>
                                    </div>
                                    <div className="gutter-margin position-absolute w-100" style={{ height: '27px', pointerEvents: 'none', background: `linear-gradient(0deg, rgba(127, 127, 127, ${this.state.commentListBottomScroll * 0.27}) 0%, rgba(0, 0, 0, 0) 100%)`, 'z-index': '1', 'bottom': '0' }}></div>
                                </div>

                                <Container className="mb-2 py-0" fluid>
                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                    <Row className="bg-white py-3 align-items-center">
                                        <Col className="px-3">
                                            <ContentEditable onKeyDown={(e) => this.sendMessageEnter(e)} tabIndex={0} value={this.state.message} onFocus={(e) => this.didFocusOn(null, null, null)} onChange={(e) => this.setState({ message: e.target.value })} className={`form-control h-auto text-break no-box-shadow caret-${this.state.color} border-focus-${this.state.color}`} />
                                        </Col>
                                    </Row>
                                    <hr className="row" style={{marginBlockStart: 0, marginBlockEnd: 0}} />
                                </Container>
                                <div className="d-grid gap-2">
                                    <Button className='mb-2' variant="primary" onClick={() => this.sendMessage()} disabled={this.state.message.trim().length == 0}>Send</Button>
                                </div>
                            </Col>
                        </Row>
                    </Container>
                    <AddTargetLanguageModal project={this.state.project} show={this.state.showAddTargetLanguageModal} onHide={() => this.toggleAddTargetLanguageModal(false)} didCancel={() => this.toggleAddTargetLanguageModal(false)} onFinish={(t) => this.addedNewTargetTranslation(t)} />
                    <InviteUserModal project={this.state.project} show={this.state.showInviteUserModal} onHide={() => this.toggleInviteUserModal(false)} didCancel={() => this.toggleInviteUserModal(false)} onFinish={() => this.toggleInviteUserModal(false)} />
                    <EditFragmentModal ws={this.ws} project={this.state.project} fragment={this.state.showEditFragmentModal} show={!!this.state.showEditFragmentModal} onHide={() => this.toggleShowEditFragmentModal(null)} didCancel={() => this.toggleShowEditFragmentModal(null)} onFinish={() => this.toggleShowEditFragmentModal(null)} />
                    <AutoSyncModal project={this.state.project} show={this.state.showAutoSyncModal} onHide={() => this.toggleShowAutoSyncModal(false)} didCancel={() => this.toggleShowAutoSyncModal(false)} onFinish={() => this.toggleShowAutoSyncModal(false)} />
                    <SystemImportModal project={this.state.project} show={this.state.showSystemImportModal} onHide={() => this.toggleShowSystemImportModal(false)} didCancel={() => this.toggleShowSystemImportModal(false)} onFinish={() => this.toggleShowSystemImportModal(false)} />
                    <FragmentEmbedModal project={this.state.project} fragment={this.state.showFragmentEmbed} onHide={() => this.showFragmentEmbed(null)} />
                    {this.state.canWrite && <ShareURLModal project={this.state.project} show={this.state.showShareURLModal} onHide={() => this.toggleShareURLModal(false)} didCancel={() => this.toggleShareURLModal(false)} onFinish={() => this.toggleShareURLModal(false)} />}
                </div>}
            </div>
        );
    }
}

Project.contextType = UserContext;
export default withRouter(Project);
