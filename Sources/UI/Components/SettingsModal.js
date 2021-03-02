import { withRouter } from 'react-router';
import React from 'react';
import _ from 'underscore';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';

class SettingsModal extends React.Component {

    constructor(props) {
        super(props);
        this.state = {
            token: '',
            showToken: false
        };
    }

    componentDidMount() {
        this.loadToken();
    }

    async loadToken() {
        const response = await fetch('/api/settings/token');
        const token = await response.text();
        if (response.ok) {
            this.setState({ token });
        }
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

    async save(e, change) {
        const data = this.props.user.settings;
        change(data);
        await fetch(`/api/me/settings`, {
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

    render() {
        return (
            <Modal {...this.props} size="lg" aria-labelledby="contained-modal-title-vcenter" centered>
                <Modal.Header closeButton>
                    <Modal.Title id="contained-modal-title-vcenter">
                        Settings
                    </Modal.Title>
                </Modal.Header>

                {this.props.user && <Modal.Body>
                    <h5>Anki</h5>
                    <Form.Group className='mb-3' controlId="settingsShowFieldPreview">
                        <Form.Check defaultChecked={this.props.user.settings.anki.showFieldPreview} onChange={(e) => this.save(e, (s) => s.anki.showFieldPreview = e.target.checked)} type="checkbox" label="Show Field Preview" />
                    </Form.Group>

                    <h5>Reader</h5>
                    <Form.Group className='mb-3' controlId="settingsShowCardForm">
                        <Form.Check defaultChecked={this.props.user.settings.reader.showCreateNoteForm} onChange={(e) => this.save(e, (s) => s.reader.showCreateNoteForm = e.target.checked)} type="checkbox" label="Show Create Note Form" />
                    </Form.Group>

                    <h5>UI</h5>
                    <Form.Group className='mb-3' controlId="settingsPrefersColorContrast">
                        <Form.Check defaultChecked={this.props.user.settings.ui.prefersColorContrast} onChange={(e) => this.save(e, (s) => s.ui.prefersColorContrast = e.target.checked)} type="checkbox" label="Prefer Color Contrast" />
                        <Form.Text className="text-muted">
                            Any feedback on additional places that could be addressed would be well appreciated. Use the "Feedback" link at the bottom of the page.
                        </Form.Text>
                    </Form.Group>

                    {this.props.user.permissions.includes('api') && <>
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
