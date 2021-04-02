import React from 'react';

import Alert from 'react-bootstrap/Alert';
import Badge from 'react-bootstrap/Badge';
import Button from 'react-bootstrap/Button';
import Col from 'react-bootstrap/Col';
import Dropdown from 'react-bootstrap/Dropdown';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import Row from 'react-bootstrap/Row';

import ContentEditable from './../../Common/ContentEditable';
import CreateNoteForm from './CreateNoteForm';

class CreateNoteModal extends React.Component {

    render() {
        return (
            <Modal {...this.props} size='lg' centered>
                <Modal.Header closeButton>
                    <Modal.Title>
                        Add Note
                    </Modal.Title>
                </Modal.Header>

                <Modal.Body>
                    <CreateNoteForm {...this.props} />
                </Modal.Body>
            </Modal>
        );
    }

}

export default CreateNoteModal;
