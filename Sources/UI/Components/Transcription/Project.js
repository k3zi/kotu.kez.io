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
import ResponsiveEmbed from 'react-bootstrap/ResponsiveEmbed'
import Row from 'react-bootstrap/Row';
import Spinner from 'react-bootstrap/Spinner';
import Table from 'react-bootstrap/Table';
import YouTube from 'react-youtube';

import AddTargetLanguageModal from "./AddTargetLanguageModal";

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
    },
);

class ContentEditable extends React.Component {

    getDOMNode() {
        return ReactDOM.findDOMNode(this);
    }

    shouldComponentUpdate(nextProps) {
        return nextProps.value !== this.getDOMNode().innerText;
    }

    componentDidUpdate() {
        if (this.props.value !== this.getDOMNode().innerText) {
           this.getDOMNode().innerText = this.props.value;
        }
    }

    emitChange() {
        const value = this.getDOMNode().innerText;
        if (this.props.onChange && value !== this.lastText) {
            this.props.onChange({
                target: {
                    value: value
                }
            });
        }
        this.lastText = value;
    }

    render() {
        return <div {...this.props} onInput={() => this.emitChange()} onBlur={() => this.emitChange()} contentEditable>
            {this.props.value || ""}
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
            videoDuration: 0,
            currentTime: 0,
            baseLanguageText: "",
            targetLanguageText: "",
            player: null,
            updateQueue: [],
            isSubmittingUpdate: false
        };
    }

    componentDidMount() {
        this.loadProject();
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

    async addedNewTargetTranslation(translation) {
        await this.loadProject(translation);
        this.toggleAddTargetLanguageModal(false);
    }

    videoOnReady(e) {
        this.setState({
            videoDuration: e.target.getDuration(),
            player: e.target
        });

        e.target.seekTo(this.nextStartTime());
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

    async addToUpdateQueue(fragment, translation, text) {
        const updateQueue = this.state.updateQueue;
        let subtitle = fragment.subtitles.filter(s => s.translation.id == translation.id)[0];
        if (subtitle) {
            subtitle.text = text;
        } else {
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
            if (!response.ok) return;
            subtitle = await response.json();
            fragment.subtitles.push(subtitle);
            this.setState({ fragments: this.state.fragments });
            return;
        }
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

    render() {
        return (
            <div>
                {!this.state.project && <h1 className="text-center"><Spinner animation="border" variant="secondary" /></h1>}

                {this.state.project && <div>
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
                                                        <Badge onClick={() => this.state.player.seekTo(fragment.startTime)} variant="primary-inverted">{this.formatTime(fragment.startTime)}</Badge>
                                                    </Col>
                                                    <Col className="px-0">
                                                        <ContentEditable value={this.baseSubtitleForFragment(fragment).text} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedBaseTranslation, e.target.value)} className={`form-control h-auto text-break no-box-shadow`} style={{"caret-color": "#007bff"}} />
                                                        {this.state.selectedTargetTranslation && <ContentEditable value={this.targetSubtitleForFragment(fragment) ? this.targetSubtitleForFragment(fragment).text : ""} onChange={(e) => this.addToUpdateQueue(fragment, this.state.selectedTargetTranslation, e.target.value)}  className="form-control h-auto text-break mt-2 no-box-shadow" style={{"caret-color": "#007bff"}} />}
                                                    </Col>
                                                    <Col xs="auto" className="text-center align-self-center">
                                                        <Badge onClick={() => this.state.player.seekTo(fragment.endTime)} variant="primary-inverted">{this.formatTime(fragment.endTime)}</Badge>
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
                                            <Badge onClick={() => this.state.player.seekTo(this.nextStartTime())} variant="primary-inverted">{this.formatTime(this.nextStartTime())}</Badge>
                                        </Col>
                                        <Col className="px-0">
                                            <ContentEditable value={this.state.baseLanguageText} onChange={(e) => this.setState({ baseLanguageText: e.target.value })} className={`form-control h-auto text-break no-box-shadow`} style={{"caret-color": "#007bff"}} />
                                            {this.state.selectedTargetTranslation && <ContentEditable value={this.state.targetLanguageText} onChange={(e) => this.setState({ targetLanguageText: e.target.value })}  className="form-control h-auto text-break mt-2 no-box-shadow" style={{"caret-color": "#007bff"}} />}
                                        </Col>
                                        <Col xs="auto" className="text-center align-self-center">
                                            <Badge variant="primary-inverted">{this.formatTime(this.state.currentTime)}</Badge>
                                        </Col>
                                    </Row>
                                    <hr className="row" style={{"margin-block-start": 0, "margin-block-end": 0}} />
                                </Container>

                                {this.state.selectedBaseTranslation && !this.state.selectedBaseTranslation.isOriginal && <Alert className="mt-1 mb-2" variant="secondary">Switch to the original transcription to add more fragments.</Alert>}
                                <Button variant="primary" onClick={() => this.addFragment()} disabled={!this.state.selectedBaseTranslation || !this.state.selectedBaseTranslation.isOriginal || !this.state.baseLanguageText || this.state.baseLanguageText.trim().length == 0} block>Add Fragment</Button>
                            </Col>
                            <Col>
                                <ResponsiveEmbed aspectRatio="16by9">
                                    <YouTube videoId={this.state.project.youtubeID} onReady={(e) => this.videoOnReady(e)} onPause ={(e) => this.onPause(e)} opts={{ playerVars: { modestbranding: 1, rel: 0, showinfo: 0, ecver: 2 }}}/>
                                </ResponsiveEmbed>
                            </Col>
                        </Row>
                    </Container>
                    <AddTargetLanguageModal project={this.state.project} show={this.state.showAddTargetLanguageModal} onHide={() => this.toggleAddTargetLanguageModal(false)} didCancel={() => this.toggleAddTargetLanguageModal(false)} onFinish={(t) => this.addedNewTargetTranslation(t)} />
                </div>}
            </div>
        )
    }
}

export default withRouter(Project);
