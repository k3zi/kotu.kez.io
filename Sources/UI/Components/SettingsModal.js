import { withRouter } from 'react-router';
import React from 'react';
import _ from 'underscore';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import ListGroup from 'react-bootstrap/ListGroup';
import Modal from 'react-bootstrap/Modal';
import ProgressBar from 'react-bootstrap/ProgressBar';

class SettingsModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            token: '',
            showToken: false,
            dictionary: {
                isSubmitting: false,
                message: null,
                didError: false
            },
            dictionaries: [],
            keybind: this.emptyKeybind(),
            isListeningForKeybind: null,
            pressedKeys: []
        };
    }

    componentDidMount() {
        this.loadToken();
        this.loadDictionaries();
        setInterval(() => {
            if (this.props.show)
                this.loadDictionaries();
        }, 5000);
    }

    componentDidUpdate(prevProps) {
        if (prevProps.show != this.props.show) {
            this.loadDictionaries();
        }
    }

    async loadToken() {
        const response = await fetch('/api/settings/token');
        const token = await response.text();
        if (response.ok) {
            this.setState({ token });
        }
    }

    async loadDictionaries() {
        const response = await fetch('/api/dictionary/all');
        if (response.ok) {
            const dictionaries = await response.json();
            for (const [i, d] of dictionaries.entries()) {
                d.order = i;
            }
            this.setState({ dictionaries });

            if (!this.state.dictionary.didError && this.state.dictionary.message && dictionaries.filter(d => d.insertJob).length === 0) {
                this.state.dictionary.message = null;
                this.setState({ dictionary: this.state.dictionary });
            }
        }
    }

    canMoveDictionaryUp(dictionary) {
        const index = this.state.dictionaries.indexOf(dictionary);
        return index > 0;
    }

    moveDictionaryUp(dictionary) {
        if (!this.canMoveDictionaryUp(dictionary)) {
            return;
        }
        const index = this.state.dictionaries.indexOf(dictionary);
        this.state.dictionaries[index] = this.state.dictionaries[index - 1];
        this.state.dictionaries[index].order = index;
        this.state.dictionaries[index - 1] = dictionary;
        this.state.dictionaries[index - 1].order = index - 1;
        this.setState({ dictionaries: this.state.dictionaries });
        this.updateDictionaries();
    }

    canMoveDictionaryDown(dictionary) {
        const index = this.state.dictionaries.indexOf(dictionary);
        return index < (this.state.dictionaries.length - 1) && index >= 0;
    }

    moveDictionaryDown(dictionary) {
        if (!this.canMoveDictionaryDown(dictionary)) {
            return;
        }
        const index = this.state.dictionaries.indexOf(dictionary);
        this.state.dictionaries[index] = this.state.dictionaries[index + 1];
        this.state.dictionaries[index].order = index;
        this.state.dictionaries[index + 1] = dictionary;
        this.state.dictionaries[index + 1].order = index + 1;
        this.setState({ dictionaries: this.state.dictionaries });
        this.updateDictionaries();
    }

    async regenerateToken() {
        const response = await fetch('/api/settings/regenerateToken', {
            method: 'POST'
        });
        const token = await response.text();
        if (response.ok) {
            this.setState({ token });
        }
    }

    async save(change) {
        const data = this.props.user.settings;
        change(data);
        await fetch('/api/me/settings', {
            method: 'PUT',
            body: JSON.stringify(data),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        if (this.props.onSave) {
            this.props.onSave();
        }
    }

    keybindFromEvent(e) {
        return {
            key: e.key,
            ctrlKey: e.ctrlKey,
            shiftKey: e.shiftKey,
            altKey: e.altKey,
            metaKey: e.metaKey
        };
    }

    onKeyDown(e) {
        e.preventDefault();
        this.state.pressedKeys[e.key] = true;
        const partialKeybind = this.keybindFromEvent(e);
        const keybind = this.state.keybind;
        if (!e.getModifierState(partialKeybind.key) && partialKeybind.key && !keybind.keys.includes(partialKeybind.key)) {
            keybind.keys.push(partialKeybind.key);
        }
        keybind.ctrlKey = keybind.ctrlKey || partialKeybind.ctrlKey;
        keybind.shiftKey = keybind.shiftKey || partialKeybind.shiftKey;
        keybind.altKey = keybind.altKey || partialKeybind.altKey;
        keybind.metaKey = keybind.metaKey || partialKeybind.metaKey;
        this.setState({ keybind, isListeningForKeybind: e.target.dataset.settingPath });
    }

    onKeyUp(e, change) {
        e.preventDefault();
        this.state.pressedKeys[e.key] = false;
        // The Meta key impedes other keyup events so assume that all keys are unpressed when the meta key is.
        if (e.key.startsWith('Meta') || Object.values(this.state.pressedKeys).every(k => !k)) {
            const keybind = this.state.keybind;
            this.setState({ isListeningForKeybind: null, keybind: this.emptyKeybind(), pressedKeys: [] });
            this.save((s) => change(s, keybind));
            e.target.blur();
        }
    }

    emptyKeybind() {
        return {
            keys: [],
            ctrlKey: false,
            shiftKey: false,
            altKey: false,
            metaKey: false
        };
    }

    keysFromKeybind(kb) {
        const replacements = {
            ' ': 'Space',
            'ArrowLeft': '◄',
            'ArrowRight': '►',
            'ArrowDown': '▼',
            'ArrowUp': '▲'
        };
        return [
            kb.ctrlKey ? 'Ctrl' : '',
            kb.shiftKey ? 'Shift' : '',
            kb.altKey ? '⌥' : '',
            kb.metaKey ? '⌘' : '',
            ...(kb.keys.sort().map(k => replacements[k] !== undefined ? replacements[k] : k))
        ].filter(k => k.length > 0);
    }

    renderKeybind(label, path, get, set) {
        const setting = get(this.props.user.settings) || 'disabled';
        return (
            <Form.Group className='d-flex mb-3 align-items-center'>
                <span className='text-nowrap col-4 col-lg-3 text-end px-2'>{label}</span>
                <InputGroup>
                    <div className='form-control readonly d-flex align-items-center'>
                        {setting !== 'disabled' && this.keysFromKeybind(setting).map((kb, i) =>
                            <>
                                {i > 0 && <span className='px-1'>+</span>}
                                <kbd className='px-3' style={{ lineHeight: 1.25 }}>{kb}</kbd>
                            </>
                        )}
                        {setting === 'disabled' && 'Disabled'}
                    </div>
                    <Form.Control
                        value={''}
                        className={this.state.isListeningForKeybind === path ? 'recording' : ''}
                        data-setting-path={path}
                        placeholder={this.state.isListeningForKeybind === path ? 'Recording...' : 'Enter a new keybinding'}
                        onKeyDown={(e) => this.onKeyDown(e)}
                        onKeyUp={(e) => this.onKeyUp(e, (s, kb) => set(s, kb))}
                    />
                    <Button onClick={() => this.save((s) => set(s, 'disabled'))} disabled={setting === 'disabled'} variant="danger" type='submit'>Remove</Button>
                </InputGroup>
            </Form.Group>
        );
    }

    async uploadDictionary(e) {
        e.preventDefault();
        this.setState({ dictionary: { isSubmitting: true, didError: false, message: null }});

        const response = await fetch('/api/dictionary/upload', {
            method: 'POST',
            body: new FormData(e.target)
        });
        const result = await response.json();

        this.setState({
            dictionary: {
                isSubmitting: false,
                didError: result.error,
                message: result.error ? result.reason : (result.insertJob ? 'Processing dictionary. This may take some time but you don\'t have to stay on this page.' : 'Dictionary added.')
            }
        });
        await this.loadDictionaries();
    }

    async updateDictionaries() {
        await fetch('/api/dictionary/all', {
            method: 'PUT',
            body: JSON.stringify(this.state.dictionaries),
            headers: {
                'Content-Type': 'application/json'
            }
        });
        await this.loadDictionaries();
    }

    async removeDictionary(dictionary) {
        await fetch(`/api/dictionary/${dictionary.id}`, {
            method: 'DELETE'
        });
        await this.loadDictionaries();
    }

    render() {
        return (
            <Modal {...this.props} size="lg" centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        Settings
                    </Modal.Title>
                </Modal.Header>

                {this.props.user && <Modal.Body>
                    <h5>Anki</h5>
                    <Form.Group className='mb-3' controlId="settingsShowFieldPreview">
                        <Form.Check defaultChecked={this.props.user.settings.anki.showFieldPreview} onChange={(e) => this.save((s) => s.anki.showFieldPreview = e.target.checked)} type="checkbox" label="Show Field Preview" />
                    </Form.Group>

                    <hr />

                    <h5>Dictionaries</h5>
                    <ListGroup className="mb-3">
                        {this.state.dictionaries.map((dictionary, i) => {
                            return <ListGroup.Item key={i} variant={dictionary.insertJob ? (dictionary.insertJob.isComplete ? 'danger' : 'warning') : 'secondary'}>
                                <div className='d-flex justify-content-between'>
                                    <div className='d-flex justify-content-start align-items-center'>
                                        <div>
                                            <i onClick={() => this.moveDictionaryUp(dictionary)} style={{ cursor: 'pointer', opacity: this.canMoveDictionaryUp(dictionary) ? 1 : 0.25 }} className='bi bi-chevron-up'></i>
                                            <br />
                                            <i onClick={() => this.moveDictionaryDown(dictionary)} style={{ cursor: 'pointer', opacity: this.canMoveDictionaryDown(dictionary) ? 1 : 0.25 }} className='bi bi-chevron-down'></i>
                                        </div>
                                        <span className='px-3'>{dictionary.name}{dictionary.insertJob && dictionary.insertJob.errorMessage && dictionary.insertJob.errorMessage.length && `(${dictionary.insertJob.errorMessage})`}</span>
                                    </div>
                                    <span className='float-end text-danger d-flex align-items-center fs-3' style={{ cursor: 'pointer' }} onClick={() => this.removeDictionary(dictionary)}><i className="bi bi-x"></i></span>
                                </div>
                                {dictionary.insertJob && !dictionary.insertJob.isComplete && <ProgressBar animated now={Math.round(dictionary.insertJob.progress * 100)} /> }
                            </ListGroup.Item>;
                        })}
                    </ListGroup>
                    <h6>Add Dictionary</h6>
                    <Form onSubmit={(e) => this.uploadDictionary(e)}>
                        <Form.Group className='mb-3' controlId="settingsAddDictionary">
                            <InputGroup className="mb-1">
                                <Form.Control type="file" name="dictionaryFile" custom />
                                <Button variant="primary" type='submit' disabled={this.state.dictionary.isSubmitting}>
                                    {this.state.dictionary.isSubmitting ? 'Uploading...' : 'Upload'}
                                </Button>
                            </InputGroup>
                            <Form.Text className="text-muted">
                                Currently コツ only accepts .mkd files. Learn more about this format on the Help page.
                            </Form.Text>
                            {this.state.dictionary.didError && <Alert variant="danger" className='mt-3' onClose={() => { this.state.dictionary.didError = false; this.state.dictionary.message = null; this.setState({ dictionary: this.state.dictionary }); }} dismissible>
                                {this.state.dictionary.message}
                            </Alert>}
                            {!this.state.dictionary.didError && this.state.dictionary.message && <Alert variant="info" className='mt-3' onClose={() => { this.state.dictionary.message = null; this.setState({ dictionary: this.state.dictionary}); }} dismissible>
                                {this.state.dictionary.message}
                            </Alert>}
                        </Form.Group>
                    </Form>

                    <hr />

                    <h5><i class='bi bi-keyboard'></i> Keybindings</h5>
                    <h6>Anki</h6>
                    {this.renderKeybind('Show Answer', 'anki.keybinds.showAnswer', (s) => s.anki.keybinds.showAnswer, (s, kb) => s.anki.keybinds.showAnswer = kb)}
                    {this.renderKeybind('Grade: 0', 'anki.keybinds.grade0', (s) => s.anki.keybinds.grade0, (s, kb) => s.anki.keybinds.grade0 = kb)}
                    {this.renderKeybind('Grade: 1', 'anki.keybinds.grade1', (s) => s.anki.keybinds.grade1, (s, kb) => s.anki.keybinds.grade1 = kb)}
                    {this.renderKeybind('Grade: 2', 'anki.keybinds.grade2', (s) => s.anki.keybinds.grade2, (s, kb) => s.anki.keybinds.grade2 = kb)}
                    {this.renderKeybind('Grade: 3', 'anki.keybinds.grade3', (s) => s.anki.keybinds.grade3, (s, kb) => s.anki.keybinds.grade3 = kb)}
                    {this.renderKeybind('Grade: 4', 'anki.keybinds.grade4', (s) => s.anki.keybinds.grade4, (s, kb) => s.anki.keybinds.grade4 = kb)}
                    {this.renderKeybind('Grade: 5', 'anki.keybinds.grade5', (s) => s.anki.keybinds.grade5, (s, kb) => s.anki.keybinds.grade5 = kb)}

                    <h6>YouTube</h6>
                    {this.renderKeybind('Next Subtitle', 'youTube.keybinds.nextSubtitle', (s) => s.youTube.keybinds.nextSubtitle, (s, kb) => s.youTube.keybinds.nextSubtitle = kb)}
                    {this.renderKeybind('Previous Subtitle', 'youTube.keybinds.previousSubtitle', (s) => s.youTube.keybinds.previousSubtitle, (s, kb) => s.youTube.keybinds.previousSubtitle = kb)}

                    <hr />

                    <h5>Reader</h5>
                    <Form.Group className='mb-3' controlId="settingsShowCardForm">
                        <Form.Check defaultChecked={this.props.user.settings.reader.showCreateNoteForm} onChange={(e) => this.save((s) => s.reader.showCreateNoteForm = e.target.checked)} type="checkbox" label="Show Create Note Form" />
                    </Form.Group>

                    <Form.Group className='mb-3' controlId="settingsReaderAutoplay">
                        <Form.Check defaultChecked={this.props.user.settings.reader.autoplay} onChange={(e) => this.save((s) => s.reader.autoplay = e.target.checked)} type="checkbox" label="Enable Autoplay" />
                    </Form.Group>

                    <Form.Group controlId="settingsReaderAutoplayDelay" className='mb-3'>
                        <Form.Label>Autoplay Delay</Form.Label>
                        <InputGroup>
                            <Form.Control value={`${this.props.user.settings.reader.autoplayDelay.toFixed(1)} seconds`} readOnly />
                            <Button variant="outline-secondary" onClick={(e) => this.save((s) => s.reader.autoplayDelay = Math.max((s.reader.autoplayDelay || 0) - 0.5, 0))}>
                                -
                            </Button>
                            <Button variant="outline-secondary" onClick={(e) => this.save((s) => s.reader.autoplayDelay = Math.min((s.reader.autoplayDelay || 0) + 0.5, 60)) }>
                                +
                            </Button>
                        </InputGroup>
                    </Form.Group>

                    <Form.Group className='mb-3' controlId="settingsReaderAutoplayScroll">
                        <Form.Check defaultChecked={this.props.user.settings.reader.autoplayScroll} onChange={(e) => this.save((s) => s.reader.autoplayScroll = e.target.checked)} type="checkbox" label="Scroll After Autoplay" />
                        <Form.Text className="text-muted">
                            Scrolls to the next line after the autoplay delay.
                        </Form.Text>
                    </Form.Group>

                    <hr />

                    <h5>Tests</h5>
                    <h6>Pitch Accent</h6>
                    <Form.Group className='mb-3' controlId="settingsTestsPitchAccentShowFurigana">
                        <Form.Check defaultChecked={this.props.user.settings.tests && this.props.user.settings.tests.pitchAccent && this.props.user.settings.tests.pitchAccent.showFurigana} onChange={(e) => this.save((s) => s.tests.pitchAccent.showFurigana = e.target.checked)} type="checkbox" label="Show Furigana Over Kanji" />
                    </Form.Group>

                    <hr />

                    <h5>UI</h5>
                    <Form.Group className='mb-3' controlId="settingsPrefersColorContrast">
                        <Form.Check defaultChecked={this.props.user.settings.ui.prefersColorContrast} onChange={(e) => this.save((s) => s.ui.prefersColorContrast = e.target.checked)} type="checkbox" label="Prefer Color Contrast" />
                        <Form.Text className="text-muted">
                            Any feedback on additional places that could be addressed would be well appreciated. Use the "Feedback" link at the bottom of the page.
                        </Form.Text>
                    </Form.Group>
                    <Form.Group className='mb-3' controlId="settingsPrefersDarkMode">
                        <Form.Check defaultChecked={this.props.user.settings.ui.prefersDarkMode} onChange={(e) => this.save((s) => s.ui.prefersDarkMode = e.target.checked)} type="checkbox" label="Prefer Dark Mode" />
                    </Form.Group>
                    <Form.Group className='mb-3' controlId="settingsPrefersHorizontalText">
                        <Form.Check defaultChecked={this.props.user.settings.ui.prefersHorizontalText} onChange={(e) => this.save((s) => s.ui.prefersHorizontalText = e.target.checked)} type="checkbox" label="Prefer Horizontal Text" />
                    </Form.Group>

                    <hr />

                    <h5>Word Status (Experimental)</h5>
                    <Form.Group className='mb-3' controlId="settingsWordStatusIsEnabled">
                        <Form.Check defaultChecked={this.props.user.settings.wordStatus.isEnabled} onChange={(e) => this.save((s) => s.wordStatus.isEnabled = e.target.checked)} type="checkbox" label="Enable" />
                        <Form.Text className="text-muted">
                            This feature is still experimental. Please make sure to leave feedback if you run in to any issues or have suggestions.
                        </Form.Text>
                    </Form.Group>

                    {this.props.user.permissions.includes('api') && <>
                        <hr />
                        <h5>API</h5>
                        <Form.Group className='mb-3' controlId="settingsShowCardForm">
                            <InputGroup>
                                <Form.Control value={this.state.showToken ? this.state.token : '(Hidden)'} readOnly />
                                <Button variant="outline-secondary" onClick={() => this.setState({ showToken: !this.state.showToken })}>
                                    {this.state.showToken ? 'Hide' : 'Show'}
                                </Button>
                                <Button variant="outline-secondary" onClick={() => this.regenerateToken()}>
                                    Regenerate
                                </Button>
                            </InputGroup>
                        </Form.Group>
                    </>}
                </Modal.Body>}
            </Modal>
        );
    }

}

export default SettingsModal;
