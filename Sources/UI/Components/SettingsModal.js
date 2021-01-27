import { withRouter } from 'react-router';
import React from 'react';
import _ from 'underscore';

import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Form from 'react-bootstrap/Form';
import Modal from 'react-bootstrap/Modal';

class SettingsModal extends React.Component {

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
                </Modal.Body>}
            </Modal>
        );
    }

}

export default SettingsModal;
